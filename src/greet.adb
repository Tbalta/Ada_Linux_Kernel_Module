-- src/greet.adb
with System;     use System;
with Interfaces; use Interfaces;

package body Greet is
    function Ada_Greet return Integer is
        str : constant String := "Hello from Ada" & Integer'Image (42);
    begin
        pr_info (str'Address, str'Length);
        return 0;
    end Ada_Greet;

    procedure Ada_Goodbye is
        str : constant String := "Goodbye from Ada";
    begin
        pr_info (str'Address, str'Length);
    end Ada_Goodbye;
end Greet;
