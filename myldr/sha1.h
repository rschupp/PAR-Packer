typedef struct _SHA_INFO SHA_INFO;

extern SHA_INFO* sha_init();
extern void sha_update(SHA_INFO *sha_info, unsigned char *buffer, int count);
extern void sha_final(unsigned char digest[20], SHA_INFO *sha_info);

