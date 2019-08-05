#include "target_2.h"
#include <target_1.h>

#include <iostream>

int main (int arg_c, char ** arg_v) {
    std::cout << "SUPER CALL: " << this_super_function (12) << std::endl;
    return 0;
}