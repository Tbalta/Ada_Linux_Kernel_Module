with System;
with Interfaces;

package Greet is
    function Ada_Greet return Integer;
    pragma Export (C, Ada_Greet, "ada_greet");

    procedure Ada_Goodbye;
    pragma Export (C, Ada_Goodbye, "ada_goodbye");

    --  Import pr_info as a wrapper for the C function pr_info_wrapper
    --  Note that System.Address can be considered as a void pointer.
    --  Because in Ada strings are not null terminated, we also need to pass the length.
    procedure pr_info (msg : System.Address; len : Interfaces.Integer_32);
    pragma Import (Ada, pr_info, "pr_info_wrapper");

end Greet;
