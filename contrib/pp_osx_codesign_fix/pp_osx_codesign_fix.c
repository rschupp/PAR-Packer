/* -*- C -*- main.c */

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <mach-o/loader.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

struct stat buffer;
int         status;

static void *load_bytes(FILE *obj_file, off_t offset, size_t size) {
  void *buf = calloc(1, size);
  fseek(obj_file, offset, SEEK_SET);
  fread(buf, size, 1, obj_file);
  return buf;
}

static void *write_bytes(FILE *obj_file, off_t offset, size_t size, void *buffer) {
  fseek(obj_file, offset, SEEK_SET);
  fwrite(buffer, size, 1, obj_file);
  return 0;
}

int main(int argc, char *argv[]) {
  if (argc < 2 || strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
    printf("Usage: %s <path to pp Mach-O binary>\n", argv[0]);
    return 1;
  }
  const char *filename = argv[1];
  FILE *obj_file = fopen(filename, "r+b");
  if (obj_file == NULL) {
    printf("'%s' could not be opened.\n", argv[1]);
    return 1;
  }

  /* Get exe size */
  off_t exesize;
  status = stat(filename, &buffer);
  if (status == 0) {
    exesize = buffer.st_size;
  }

  size_t header_size = sizeof(struct mach_header_64);
  struct mach_header_64 *header = load_bytes(obj_file, 0, header_size);
  off_t load_commands_offset = header_size;
  uint32_t ncmds = header->ncmds;

  off_t current_offset = load_commands_offset;
  for (uint32_t i = 0U; i < ncmds; i++) {
    struct load_command *cmd = load_bytes(obj_file, current_offset, sizeof(struct load_command));

    /* 
       __LINKEDIT.File Size = .exe size - __LINKEDIT.File Offset
       __LINKEDIT.VM Size   = .exe size - __LINKEDIT.File Offset
    */ 
    if (cmd->cmd == LC_SEGMENT_64) {
      struct segment_command_64 *segment = load_bytes(obj_file, current_offset, sizeof(struct segment_command_64));
      if (strcmp(segment->segname, "__LINKEDIT") == 0) {
        printf("Correcting __LINKEDIT\n");
        printf("  Old File Size: %i\n", (int)segment->filesize);
        segment->filesize = exesize - segment->fileoff;
        printf("  New File Size: %i\n", (int)segment->filesize);
        printf("  Old VM Size: %i\n", (int)segment->vmsize);
        segment->vmsize   = exesize - segment->fileoff;
        printf("  New VM Size: %i\n", (int)segment->vmsize);
        write_bytes(obj_file, current_offset, sizeof(struct segment_command_64), segment);
        free(segment);
      }
    }

    /* 
       LC_SYMTAB.String Table Size = .exe size - String Table Offset
    */ 
    if (cmd->cmd == LC_SYMTAB) {
      struct symtab_command *symtab = load_bytes(obj_file, current_offset, sizeof(struct symtab_command));
      printf("Correcting LC_SYMTAB\n");
      printf("  Old String Table Size: %i\n", (int)symtab->strsize);
      symtab->strsize = exesize - symtab->stroff;
      printf("  New String Table Size: %i\n", (int)symtab->strsize);
      write_bytes(obj_file, current_offset, sizeof(struct symtab_command), symtab);
      free(symtab);
    }
    
    current_offset += cmd->cmdsize;
  }

  free(header);  
  fclose(obj_file);

  (void)argc;
  return 0;
}
