* Thomson MO K7 Boot Loader by OlivierP-To8
* September 2024


(main)BootMO.asm

    org $2400

* Page 0 moniteur [$2000-$20FF] (Stack [$2087-$20CC])
* Page 0 extra-moniteur [$2100-$22FF]
* Free : [$2300-$9FFF]

Buffer_ equ $2300

K7CO    equ $20     * Lecture/écriture sur la cassette
K7MO    equ $22     * Mise en route/arrêt du moteur
DKBOOT  equ $28     * Lancement du boot

    SETDP $20

    * set S (system stack)
    lds #$20CC

    * set DP (direct page) register
    lda #$20
    tfr a,dp

Boot_loop
    * start tape
    lda #$01        * $01 for read (no delay); $02 for write (with 1 sec delay)
    swi
    fcb K7MO

    ldb #$00
    stb FileBloc_
    ldx #$0000
    stx BlocSize_

    ldy #Buffer_
    jsr ReadFile_

    * stop tape after 1/2 sec
    lda #$00
    swi
    fcb K7MO

    ldx FileExec_
    jsr ,x          * exec loaded file

    bra Boot_loop

    * reboot
    swi
    fcb DKBOOT


ReadFile_
    lda #$01        * $00 = write, read if not null
    swi
    fcb K7CO
    * A = computed checksum of data
    * B = type of block ($00 = header, $01 = content, $ff = end)
    * at Y
    * - 1 byte for the length of data (n+2; $00 means 256)
    * - n bytes of data
    * - 1 byte of expected checksum

    cmpb #$ff       * End of file
    beq ReadFileEnd_
    cmpb #$00       * File header : name
    beq ReadFile_

    jsr CopyBlock_
    bra ReadFile_

ReadFileEnd_
    rts


CopyBlock_
    pshs x,y,a,b    * Y = length + data + checksum

    tfr y,u
    pulu b          * B = length of data
    subb #2         * remove 2 bytes for length and checksum
    tfr b,a
    ldx BlocSize_   * X = block size
    abx             * X = X + B
    stx BlocSize_   * remembers processed data length

    ldb FileBloc_
    bne CopyBlockByte_  * if not 0 there is not 5 bytes bin header to process
    incb
    stb FileBloc_
    pulu b          * B = first byte of bin header ($00)
    pulu y          * Y = file size from bin header
    leay 10,y       * Y += bin header + bin tail
    sty FileSize_
    pulu y          * Y = file load address
    sty FileAddr_
    sty FileExec_   * FileExec_ = FileAddr_ by default
    suba #5         * remove the 5 bytes of bin header alreay read

CopyBlockByte_
    ldx FileAddr_
CopyBlockByteLoop_
    pulu b
    stb ,x+
    deca
    bne CopyBlockByteLoop_
    stx FileAddr_

    ldy FileSize_
    cmpy BlocSize_  * test if all file content is processed
    bne CopyBlockEnd_
    leax -2,x       * X = exec addr from bin tail (last 2 bytes)
    cmpx #$9FFF
    bhs CopyBlockEnd_ * in case the loaded file goes up to $9fff
    ldy ,x
    sty FileExec_

CopyBlockEnd_
    puls x,y,a,b
    rts


FileBloc_ FCB $00   * number of blocks processed
BlocSize_ FDB $0000 * data length of blocks processed
FileSize_ FDB $0000 * file size according to the bin header
FileAddr_ FDB $0000 * file loading address according to the bin header
FileExec_ FDB $0000 * file exec address according to the bin tail

    end $2400
