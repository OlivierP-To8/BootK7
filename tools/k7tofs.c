/*******************************************************************************
 * Rapide programme pour mettre des fichiers dans une K7 TO
 * Auteur : OlivierP-To8
 *******************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <memory.h>
#include <unistd.h>

#define MIN(a, b) (((a) < (b)) ? (a) : (b))

void ecrireBloc(FILE *k7, const char typeBloc, const char data[], int len)
{
	// En-tete de bloc :
	// Pour permettre la synchronisation de la lecture, les blocs sont
	// precedes d'une en-tete composee de 10 octets FF, suivis de 01 et 3C
	const char synchroTO[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
	fwrite(synchroTO, sizeof(synchroTO), 1, k7);
	const char blocTO[] = {0x01, 0x3C};
	fwrite(blocTO, sizeof(blocTO), 1, k7);

	fwrite(&typeBloc, 1, 1, k7);

	unsigned char taille = len;
	fwrite(&taille, 1, 1, k7);

	if (len > 0)
		fwrite(data, len, 1, k7);

    int chksum = typeBloc + taille;
	for (int i = 0; i < len; i++)
	{
		chksum += data[i];
	}
	fwrite(&chksum, 1, 1, k7);
}

void ajouterFichierContenu(FILE *k7, char *filename, unsigned char *bytes, int size)
{
	char data[256];
	memset(data, 0, sizeof(data));

    // nom du fichier (8 caractères avec espace)
	int point = strcspn(filename, ".");
	strncpy(data, filename, point);
	for (int i = point; i < 8; i++)
		strcat(data, " ");
    // extension du fichier (3 caractères avec espace)
	strcat(data, &filename[point + 1]);
	for (int i = 8; i <= 10; i++)
        if (data[i] == 0)
            data[i] = ' ';
	// type de fichier 00=Basic 01=Data 02=Binaire
	if (strncmp(&filename[point + 1], "BIN", 3) == 0)
		data[11] = 0x02;
	// mode du fichier 00=Binaire FF=Texte
    data[12] = 0x00;
	// checksum
    data[13] = 0x00;
    //- Bloc d'en-tete (type 00, longueur 20)
	ecrireBloc(k7, 0x00, data, 20);

	int ptr = 0;
	while (ptr < size)
	{
		int taille = MIN(128, size - ptr);
		//- Blocs contenant le fichier (type 01)
		// 00 type de bloc = 01
		// 01 longueur du bloc = xx (128 par défaut)
		// 02-yy contenu du fichier (yy = xx -1)
		// xx checksum
		if (taille > 0)
		{
			// printf("  Bloc %d [%d-%d]\n", taille, ptr, ptr + taille);
			ecrireBloc(k7, 0x01, &bytes[ptr], taille);
		}
		ptr += taille;
	}

	memset(data, 0, sizeof(data));
	//- Bloc de fin (type FF)
	// 00 type de bloc = FF
	// 01 longueur du bloc = 0
	// 02 checksum = FF
	ecrireBloc(k7, 0xff, data, 0);
}

void ajouterFichier(FILE *k7, char *filename)
{
	char *fileaddr = strstr(filename, ".BIN@");
	char *fileexec = NULL;
	if (fileaddr != NULL)
	{
		fileaddr[4] = 0;
		fileexec = strstr(fileaddr + 5, "@");
	}
	FILE *fi = fopen(filename, "rb");
	if (fi == NULL)
	{
		printf("impossible d'ouvrir %s\n", filename);
	}
	else
	{
		fseek(fi, 0, SEEK_END);
		int size = ftell(fi);
		int delta = 0;

		if (strstr(filename, ".BIN") != NULL)
		{
			// check header and footer of binary file and add if missing
			unsigned char header[5], footer[5];
			fseek(fi, -5, SEEK_END);
			fread(footer, 1, 5, fi);
			fseek(fi, 0, SEEK_SET);
			fread(header, 1, 5, fi);

			int sizecont = size - 10;
			if ((header[0] != 0x00) || (header[1] != (sizecont >> 8) || header[2] != (sizecont & 0xff)))
			{
				size += 10;
				delta = 5;
			}
		}

		unsigned char *fileData = malloc(size);
		memset(fileData, 0, size);
		fseek(fi, 0, SEEK_SET);

		int nbr = fread(&fileData[delta], 1, size, fi);
		fclose(fi);
		printf("lecture de %s (%d octets)\n", filename, size);
		if ((delta > 0) && (fileaddr != NULL))
		{
			int sizecont = size - 10;
			int addrload = (int)strtol(&fileaddr[5], NULL, 16);
			int addrexec = addrload;
			if (fileexec != NULL)
			{
				addrexec = (int)strtol(&fileexec[1], NULL, 16);
			}
			printf("Ajout du header et footer au fichier %s @ load %04x exec %04x\n", filename, addrload, addrexec);
			fileData[0] = 0x00;
			fileData[1] = (unsigned char)(sizecont >> 8);
			fileData[2] = (unsigned char)(sizecont & 0xff);
			fileData[3] = (unsigned char)(addrload >> 8);
			fileData[4] = (unsigned char)(addrload & 0xff);
			fileData[size - 5] = 0xff;
			fileData[size - 4] = 0x00;
			fileData[size - 3] = 0x00;
			fileData[size - 2] = (unsigned char)(addrexec >> 8);
			fileData[size - 1] = (unsigned char)(addrexec & 0xff);
		}

		ajouterFichierContenu(k7, filename, fileData, size);
	}
}

enum eTypeBloc
{
	bSynchroTO,
	bInconnu
};
#define bool int
#define true 1
#define false 0

FILE *fext = NULL;

bool lireBloc(FILE *f, unsigned char tb)
{
	bool retval = true;
	long chksum = 0;
	unsigned char c = 0;
	unsigned char nom[256] = {""};

	/**************************************
	** traitement de la longueur du bloc **
	**************************************/
	c = fgetc(f);
	int len = c;

	if (tb == 0xff)
	{
		if (fext != NULL)
		{
			fclose(fext);
			fext = NULL;
		}
	}

	/**************************************
	** lecture des données ****************
	**************************************/
	int n = 0;
	for (int i = 0; i < len; i++)
	{
		c = fgetc(f);
		chksum += c;

		if (tb == 0x01)
		{
			if (fext != NULL)
			{
				fwrite(&c, 1, 1, fext);
			}
		}
		// lecture du nom du fichier
		else if ((tb == 0x00) && (i < 11))
		{
			nom[n++] = c;
			if (i == 7)
			{
				for (int j = 7; j >= 0; j--)
				{
					if (nom[j] != ' ')
					{
						n = j + 1;
						break;
					}
				}
				nom[n++] = '.';
			}
			if (i == 10)
				nom[n++] = 0;
		}
	}

	if (tb == 0x00)
	{
		printf("Fichier %s\n", nom);
		if (fext != NULL)
		{
			fclose(fext);
		}
		if (access(nom, F_OK) == 0)
		{
			printf("Le fichier %s existe déjà !, Appuyez sur une touche pour continuer\n", nom);
			getchar();
		}
		fext = fopen(nom, "wb");
	}

	/**************************************
	** traitement du checksum *************
	**************************************/
	c = fgetc(f);

	chksum += tb;
	chksum += len;
	// checksum OK si somme(octet type bloc + octet longueur + données) modulo 256 == checksum
	retval = (chksum % 256 == c);
	if (!retval)
		printf("  /!\\ checksum KO\n");

	return retval;
}

bool extraireFichiers(FILE *k7)
{
	bool retval = true;

	if (k7 != NULL)
	{
		enum eTypeBloc tb = bInconnu;
		int nbFF = 0;
		unsigned char c = 0, prevc;

		while (!feof(k7))
		{
			prevc = c;
			c = fgetc(k7);
			if (feof(k7))
				return retval;

			switch (c)
			{
			case 0x00:
				if (tb == bSynchroTO)
				{
    				printf("Bloc entête\n");
					if (lireBloc(k7, c) == false)
						retval = false;
					tb = bInconnu;
				}
				nbFF = 0;
				break;

			case 0x01:
				if (tb == bSynchroTO)
				{
    				printf("Bloc données\n");
					if (lireBloc(k7, c) == false)
						retval = false;
					tb = bInconnu;
					nbFF = 0;
				}
				break;

			case 0xFF:
				if (tb == bSynchroTO)
				{
				    printf("Bloc fin\n");
					if (lireBloc(k7, c) == false)
						retval = false;
					tb = bInconnu;
					nbFF = 0;
				}
                else
					nbFF++;
				break;

			case 0x3C:
				if ((nbFF >= 2) && (prevc == 0x01))
				{
					tb = bSynchroTO;
					nbFF = 0;
				}
				break;

			default:
				break;
			}
		}
	}

	return retval;
}

int main(int argc, char **argv)
{
	if ((argc >= 4) && (strcmp(argv[1], "-add") == 0))
	{
		FILE *k7 = fopen(argv[2], "wb");
		if (k7 == NULL)
		{
			printf("impossible d'ouvrir %s\n", argv[2]);
		}
		else
		{
			for (int i = 3; i < argc; i++)
			{
				ajouterFichier(k7, argv[i]);
			}
			fclose(k7);
		}
	}
	else if ((argc == 3) && (strcmp(argv[1], "-ext") == 0))
	{
		FILE *k7 = fopen(argv[2], "rb");
		if (k7 == NULL)
		{
			printf("impossible d'ouvrir %s\n", argv[2]);
		}
		else
		{
			extraireFichiers(k7);
			fclose(k7);
		}
	}
	else
	{
		printf("usage : %s -add filename.k7 filename\n", argv[0]);
		printf("usage : %s -ext filename.k7\n", argv[0]);
	}
	return 0;
}
