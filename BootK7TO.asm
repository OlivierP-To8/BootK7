* Thomson TO K7 Boot Loader by OlivierP-To8
* May 2026


(main)BootK7TO.asm

    org $6600

* Page 0 moniteur [$6000-$60FF] (Stack [$608B-$60CC])
* Page 0 extra-moniteur [$6100-$62FF]
* Free : [$6300-$DFFF]

Buffer_ equ $6500

K7CO    equ $E815   * Lecture/écriture sur la cassette

K7OPC   equ $6029   * Code commande
K7STA   equ $602A   * Status

K7OPR   equ $01     * Ouvre en Lecture
K7RDC   equ $02     * Lecture d'un caractère
K7OPW   equ $04     * Ouvre en écriture
K7WRT   equ $08     * Ecriture d'un caractère
K7CLS   equ $10     * Fermeture

    SETDP $60

    * set S (system stack)
    lds #$60CC

    * set DP (direct page) register
    lda #$60
    tfr a,dp

Boot_loop
    * start tape
    ldb #K7OPR
    stb K7OPC
    jsr K7CO
    bcs Boot_loop

    ldb #$00
    stb FileBloc_
    ldx #$0000
    stx BlocSize_

    ldy #Buffer_
    jsr ReadFile_

    * stop tape
    ldb #K7CLS
    stb K7OPC
    jsr K7CO

    ldx FileExec_
    jsr ,x          * exec loaded file

    bra Boot_loop

ReadByte_
    ldb #K7RDC
    stb K7OPC
    jsr K7CO
    rts


ReadBloc_
    jsr ReadByte_
    bcs ReadBlocExit_
    cmpb #$ff       * synchro
    beq ReadBloc_
    cmpb #$01       * synchro
    beq ReadBloc_
    cmpb #$3C       * fin de synchro
    bne ReadBloc_
    jsr ReadByte_   * B = type du bloc
    bcs ReadBlocEnd_
    pshs b          * B = type du bloc
    tfr y,u
    jsr ReadByte_   * B = taille du bloc
    bcs ReadBlocEnd_
    stb ,u+
    tfr b,a         * A = taille du bloc
    inca            * lecture checksum
ReadBlocData_
    jsr ReadByte_   * lit un octet de donnée
    bcs ReadBlocEnd_
    stb ,u+
    deca
    bne ReadBlocData_
ReadBlocEnd_
    tfr b,a         * A = checksum du bloc
    puls b          * B = type de bloc
ReadBlocExit_
    rts


ReadFile_
    jsr ReadBloc_
    * A = computed checksum of data
    * B = type of block ($00 = header, $01 = content, $ff = end)
    * at Y
    * - 1 byte for the length of data (n)
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
    pulu a          * A = length of data
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
    cmpx #$DFFF
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

    end $6600
