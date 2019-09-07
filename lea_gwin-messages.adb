with LEA_GWin.MDI_Main;                 use LEA_GWin.MDI_Main;

with GWindows.Clipboard;                use GWindows.Clipboard;
with GWindows.Cursors;                  use GWindows.Cursors;
with GWindows.Message_Boxes;
with GWindows.Windows;                  use GWindows.Windows;

with Ada.Strings.Wide_Unbounded;        use Ada.Strings.Wide_Unbounded;

package body LEA_GWin.Messages is

  overriding procedure On_Click (Control : in out Message_List_Type) is
  begin
    Control.On_Double_Click;
    --  Focus back on the message list (so the keyboard is also focused there)
    Control.Focus;
  end On_Click;

  overriding procedure On_Double_Click (Control : in out Message_List_Type) is
    use LEA_LV_Ex;
    pl: Data_Access;
    mm: MDI_Main_Access;
    use HAC.UErrors;
  begin
    for i in 0 .. Control.Item_Count loop
      if Control.Is_Selected (i) then
        pl := Control.Item_Data (i);
        if pl /= null then
          mm := MDI_Main_Access (Control.mdi_main_parent);
          mm.Open_Child_Window_And_Load (pl.file, pl.line, pl.col_a, pl.col_z);
          --  At this point focus is on the editor window.
          if pl.repair.kind /= none
            --  There is a repair possible (and the tool icon is on the left of the row).
            and then Control.Point_To_Client (Get_Cursor_Position).X < 16
            --  The click happened on the tool icon.
          then
            --  !!  TBD: proc Do_repair
            GWindows.Message_Boxes.Message_Box ("Repair", pl.repair.kind'Wide_Image);  --  !!
            --  Disable repair:
            pl.repair.kind := none;
            --  Remove tool icon:
            Control.Set_Item (Control.Text(Item => i, SubItem => 0), i, Icon => 0);
          end if;
          exit;
        end if;
      end if;
    end loop;
  end On_Double_Click;

  procedure Copy_Messages (Control : in out Message_List_Type) is
    cols : Natural := 0;
    res  : GString_Unbounded;
    --  We separate columns with Tabs - useful when pasting into a spreadsheet.
    HTab : constant GCharacter := GCharacter'Val (9);
  begin
    loop
      declare
        cn : constant GString := Control.Column_Text (cols);
      begin
        exit when cn = "";
        if cols > 0 then
          res := res & HTab;
        end if;
        res := res & cn;
      end;
      cols := cols + 1;
    end loop;
    res := res & NL;
    for i in 0 .. Control.Item_Count - 1 loop
      for c in 0 .. cols - 1 loop
        if c > 0 then
          res := res & HTab;
        end if;
        res := res & Control.Text (i, c);
      end loop;
      res := res & NL;
    end loop;
    --
    --  Now, send the whole stuff to the clipboard.
    --
    Clipboard_Text (Window_Access (Control.mdi_main_parent).all, res);
  end Copy_Messages;

end LEA_GWin.Messages;
