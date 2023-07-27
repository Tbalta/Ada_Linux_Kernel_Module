#include <linux/module.h>
#include <linux/printk.h>

extern void adainit (void);
extern int ada_greet (void);
__init int my_init(void)
{
    adainit();
    return ada_greet();
}

extern void adafinal (void);
extern void ada_goodbye (void);
__exit void my_exit(void)
{
    ada_goodbye();
    adafinal();
}

module_init(my_init);
module_exit(my_exit);

MODULE_LICENSE("GPL v2");