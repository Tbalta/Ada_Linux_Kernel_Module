-- src/greet.ads
with System;
with Interfaces;

package Greet is
    function Ada_Greet return Integer;
    pragma Export (C, Ada_Greet, "ada_greet");

    procedure Ada_Goodbye;
    pragma Export (C, Ada_Goodbye, "ada_goodbye");

    --  System.Address can be considered as a void pointer.
    --  Ada's strings aren't null terminated so we need to indicate the length.
    procedure pr_info (msg : System.Address; len : Interfaces.Integer_32);
    pragma Import (C, pr_info, "pr_info_wrapper");

end Greet;
