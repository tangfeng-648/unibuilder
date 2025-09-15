#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <limits.h>
#include <stdlib.h>
#include <time.h>
#include <openssl/md5.h>
#include "rkrom.h"
#include "rkafp.h"

void special_afpimage_size(const char* afpimg, struct rkfw_header* header)
{
        FILE *fp = NULL;
	unsigned long imgsize = 0;
	unsigned long size_4g = 4LL*1024*1024*1024;
	unsigned int r = 0;

        fp = fopen(afpimg, "rb");
        if (!fp)
		return;

        fseek(fp, SEEK_SET, SEEK_END);
	imgsize = ftell(fp);
	r = imgsize / size_4g;
	if (r > 0){
		header->backup_endpos = 0x49480000;
	}

	header->reserved[0] = r;

        if (fp)
                fclose(fp);
}

unsigned int import_data(const char* infile, void *head, size_t head_len, FILE *fp)
{
	FILE *in_fp = NULL;
	unsigned readlen = 0;
	unsigned char buffer[1024];

	in_fp = fopen(infile, "rb");

	if (!in_fp)
		goto import_end;

	readlen = fread(head, 1, head_len, in_fp);
	if (readlen)
	{
		fwrite(head, 1, readlen, fp);
	}

	while (1)
	{
		int len = fread(buffer, 1, sizeof(buffer), in_fp);

		if (len)
		{
			fwrite(buffer, 1, len, fp);
			readlen += len;
		}

		if (len != sizeof(buffer))
			break;
	}

import_end:
	if (in_fp)
		fclose(in_fp);

	return readlen;
}

void append_md5sum(FILE *fp)
{
	MD5_CTX md5_ctx;
	unsigned char buffer[1024];
	int i;

	MD5_Init(&md5_ctx);
	fseek(fp, 0, SEEK_SET);

	while (1)
	{
		int len = fread(buffer, 1, sizeof(buffer), fp);
		if (len)
		{
			MD5_Update(&md5_ctx, buffer, len);
		}

		if (len != sizeof(buffer))
			break;
	}

	MD5_Final(buffer, &md5_ctx);

	for (i = 0; i < 16; ++i)
	{
		fprintf(fp, "%02x", buffer[i]);
	}
}

int pack_rom(unsigned int chiptype, const char *loader_filename, int majver, int minver, int subver, const char *image_filename, const char *outfile)
{
	time_t nowtime;
	struct tm local_time;
	unsigned int i;

	struct rkfw_header rom_header = {
		.head_code = "RKFW",
		.head_len = 0x66,
		.loader_offset = 0x66
	};

	struct update_header rkaf_header;
	struct bootloader_header loader_header;

	rom_header.chip = chiptype;
	rom_header.version = (((majver) << 24) + ((minver) << 16) + (subver));
	//rom_header.version = 0x8010040;
	//printf("version=%#x \n", rom_header.version);

	if(chiptype == 0x33333043) { // rk3399
		rom_header.code = 0x01060005;
	}else if(chiptype == 0x33353638 || chiptype == 0x33353838) {
		rom_header.code = 0x02000000; // rk3568 rk3588
	}
	nowtime = time(NULL);
	localtime_r(&nowtime, &local_time);

	rom_header.year = local_time.tm_year + 1900;
	rom_header.month = local_time.tm_mon + 1;
	rom_header.day = local_time.tm_mday;
	rom_header.hour = local_time.tm_hour;
	rom_header.minute = local_time.tm_min;
	rom_header.second = local_time.tm_sec;

	FILE *fp = fopen(outfile, "wb+");
	if (!fp)
	{
		fprintf(stderr, "Can't open file %s\n, reason: %s\n", outfile, strerror(errno));
		goto pack_fail;
	}

	unsigned char buffer[0x66];
	if (1 != fwrite(buffer, 0x66, 1, fp))
		goto pack_fail;


	printf("rom version: %x.%x.%x\n",
		(rom_header.version >> 24) & 0xFF,
		(rom_header.version >> 16) & 0xFF,
		(rom_header.version) & 0xFFFF);

	printf("build time: %d-%02d-%02d %02d:%02d:%02d\n",
		rom_header.year, rom_header.month, rom_header.day,
		rom_header.hour, rom_header.minute, rom_header.second);

	printf("chip: %x\n", rom_header.chip);

	fseek(fp, rom_header.loader_offset, SEEK_SET);
	fprintf(stderr, "generate image...\n");
	rom_header.loader_length = import_data(loader_filename, &loader_header, sizeof(loader_header), fp);

	if (rom_header.loader_length <  sizeof(loader_header))
	{
		fprintf(stderr, "invalid loader :\"\%s\"\n",  loader_filename);
		goto pack_fail;
	}

	rom_header.image_offset = rom_header.loader_offset + rom_header.loader_length;
	rom_header.image_length = import_data(image_filename, &rkaf_header, sizeof(rkaf_header), fp);
	if (rom_header.image_length < sizeof(rkaf_header))
	{
		fprintf(stderr, "invalid rom :\"\%s\"\n",  image_filename);
		goto pack_fail;
	}

	rom_header.unknown2 = 1;

	rom_header.system_fstype = 0;

	for (i = 0; i < rkaf_header.num_parts; ++i)
	{
		if (strcmp(rkaf_header.parts[i].name, "backup") == 0)
			break;
	}
#if 0
	if (i < rkaf_header.num_parts)
		rom_header.backup_endpos = (rkaf_header.parts[i].nand_addr + rkaf_header.parts[i].nand_size) / 0x800;
	else
		rom_header.backup_endpos = 0;
#endif

	special_afpimage_size(image_filename, &rom_header);
	fseek(fp, 0, SEEK_SET);
	if (1 != fwrite(&rom_header, sizeof(rom_header), 1, fp))
		goto pack_fail;

	fprintf(stderr, "append md5sum...\n");
	append_md5sum(fp);
	fclose(fp);
	fprintf(stderr, "success!\n");

	return 0;
pack_fail:
	if (fp)
		fclose(fp);
	return -1;
}

int pack_rom_rk(unsigned int chiptype, const char *loader_filename, const char *image_filename, const char *outfile)
{
	//return pack_rom(chiptype, loader_filename, 8, 1, 64, image_filename, outfile);
	return pack_rom(chiptype, loader_filename, 1, 0, 0, image_filename, outfile);
}


void usage(const char *appname) {
	const char *p = strrchr(appname, '/');
	p = p ? p + 1 : appname;

	printf("Usage:\n"
			"%s [chiptype] [loader] [old image] [out image]\n\n"
			"Example:\n"
			"%s -rk3399 MiniLoaderAll.bin firmware_afp.img update.img \tRK3399 board\n"
			"%s -rk3568 MiniLoaderAll.bin firmware_afp.img update.img \tRK3568 board\n"
			"%s -rk3588 MiniLoaderAll.bin firmware_afp.img update.img \tRK3588 board\n"
			"\n"
			"Options:\n"
			"[chiptype]:\n\t-rk3399\n\t-rk3568\n\t-rk3588\n", p, p, p, p);
}

int main(int argc, char **argv)
{
	int ret = 0;
	// loader, oldimage, newimage
	if (argc == 5)
	{
		if (strcmp(argv[1], "-rk3399") == 0)
		{
			pack_rom_rk(0x33333043, argv[2], argv[3], argv[4]);
		}
		else if (strcmp(argv[1], "-rk3568") == 0)
		{
			pack_rom_rk(0x33353638, argv[2], argv[3], argv[4]);
		}
		else if (strcmp(argv[1], "-rk3588") == 0)
		{
			pack_rom_rk(0x33353838, argv[2], argv[3], argv[4]);
		}
		else
		{
			usage(argv[0]);
			return 0;
		}
	}else if (argc == 8){
		if(strcmp(argv[1], "-rk3399") == 0){
			pack_rom(0x33333043, argv[2], atoi(argv[3]), atoi(argv[4]), atoi(argv[5]), argv[6], argv[7]);
		}
		else if(strcmp(argv[1], "-rk3568") == 0){
			pack_rom(0x33353638, argv[2], atoi(argv[3]), atoi(argv[4]), atoi(argv[5]), argv[6], argv[7]);
		}
		else if(strcmp(argv[1], "-rk3588") == 0){
			pack_rom(0x33353838, argv[2], atoi(argv[3]), atoi(argv[4]), atoi(argv[5]), argv[6], argv[7]);
		}
	}
	else
	{
		usage(argv[0]);
	}

	return ret < 0 ? 1 : 0;
}
