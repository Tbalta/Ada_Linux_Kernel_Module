// src/helper.c
#include <linux/slab.h> // kmalloc, kfree


void pr_info_wrapper (const char *txt, uint32_t len)
{
    // The iso forbid variable length arrays, so we use kmalloc
    char *buff = kmalloc (len + 1, GFP_KERNEL);
    memcpy (buff, txt, len);
    // We need to add the null terminator ourselves.
    buff[len] = '\0';
    pr_info ("%s\n", buff);
    kfree (buff);
}

// adafinal symbol in case it doesn't exist
void adafinal(void)
{}
void adafinal (void) __attribute__((weak));