-- hello_ada.adb
with Text_IO; use Text_IO;

procedure Hello_Ada is
    -- Import the C function
    procedure Hello_C;
    pragma Import (C, Hello_C, "hello_c");
begin
    Hello_C;
    Put_Line ("Hello from Ada");
end Hello_Ada;
