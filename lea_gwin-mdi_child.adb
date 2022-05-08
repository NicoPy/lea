with LEA_Common.Syntax,
     LEA_Common.User_options;

with LEA_GWin.Messages,
     LEA_GWin.Modal_Dialogs,
     LEA_GWin.Options,
     LEA_GWin.Run_Windowed,
     LEA_GWin.Search_box;

with HAC_Sys.Co_Defs,
     HAC_Sys.Defs;

with GWindows.Base,
     GWindows.Common_Dialogs,
     GWindows.Cursors,
     GWindows.Menus,
     GWindows.Message_Boxes,
     GWindows.Scintilla;

with Ada.Characters.Handling,
     Ada.Calendar,
     Ada.Directories,
     Ada.Strings.Unbounded,
     Ada.Strings.Wide_Fixed,
     Ada.Strings.Wide_Unbounded,
     Ada.Text_IO.Text_Streams;

package body LEA_GWin.MDI_Child is

  use LEA_Common, MDI_Main;
  use GWindows.Message_Boxes, GWindows.Scintilla;
  use Ada.Strings.Wide_Unbounded;

  package Status_bar_parts is
    general_info      : constant := 130;
    length_and_lines  : constant := 170 + general_info;
    line_and_col      : constant := 130 + length_and_lines;
    selection         : constant := 110 + line_and_col;
    eol_indicator     : constant := 130 + selection;
    ansi_unicode      : constant := 120 + eol_indicator;
    ins_ovr           : constant :=  30 + ansi_unicode;
  end Status_bar_parts;

  overriding procedure On_Click (Bar : in out MDI_Child_Status_Bar_Type) is
    x : Integer;
    parent : MDI_Child_Type renames MDI_Child_Type (Bar.Parent.all);
    use Status_bar_parts;
    frame_width : constant := 8;  --  A hack, guessing the window frame's width
  begin
    x := GWindows.Cursors.Get_Cursor_Position.X;
    --  NB: parent.Left is the absolute position of the MDI
    --  Child window, not relative to MDI main!
    x := x - parent.Left - Bar.Left - frame_width;
    if x in length_and_lines .. line_and_col then
      Modal_Dialogs.Do_Go_to_Line (parent);
    end if;
  end On_Click;

  function Folder_Focus (MDI_Child : in MDI_Child_Type) return Boolean is
  begin
    return
      MDI_Child.MDI_Parent.opt.view_mode = Studio; --  !!  and then
      --  !! MDI_Child.Focus = MDI_Child.Folder_Tree'Unrestricted_Access;
  end Folder_Focus;

  procedure Update_status_bar (MDI_Child : in out MDI_Child_Type) is
    pos, sel_a, sel_z : Scintilla.Position;
  begin
    if MDI_Child.File_Name = Null_GString_Unbounded then
      MDI_Child.Status_Bar.Text("No file", 0);
    end if;
    if Folder_Focus(MDI_Child) then
      MDI_Child.Status_Bar.Text("Folder selected", 0);
      return;
    else
      case MDI_Child.Editor.document_kind is
        when editable_text =>
          MDI_Child.Status_Bar.Text (
            LEA_Common.Syntax.File_type_image (MDI_Child.Editor.syntax_kind), 0
          );
        when help_main =>
          MDI_Child.Status_Bar.Text ("Help", 0);
      end case;
    end if;
    MDI_Child.Status_Bar.Text(
      "Length:" & Int'Wide_Image(MDI_Child.Editor.Get_Length) &
      "     Lines:" & Integer'Wide_Image(MDI_Child.Editor.Get_Line_Count),
      1);
    pos   := MDI_Child.Editor.Get_Current_Pos;
    sel_a := MDI_Child.Editor.Get_Selection_Start;
    sel_z := MDI_Child.Editor.Get_Selection_End;
    MDI_Child.Status_Bar.Text(
      "Line:"  & Integer'Wide_Image(1 + MDI_Child.Editor.Line_From_Position(pos)) &
      " Col:" & Integer'Wide_Image(1 + MDI_Child.Editor.Get_Column(pos)),
      2);
    MDI_Child.Status_Bar.Text("Sel:" & Scintilla.Position'Wide_Image(sel_z - sel_a) &
      " (ln:" & Integer'Wide_Image(
         1 +
         MDI_Child.Editor.Line_From_Position(sel_z) -
         MDI_Child.Editor.Line_From_Position(sel_a)
      ) & ')',
      3);
    case MDI_Child.Editor.Get_EOL_Mode is
      when SC_EOL_CR =>
        MDI_Child.Status_Bar.Text("EOL: Mac (CR)",        4);
      when SC_EOL_CRLF =>
        MDI_Child.Status_Bar.Text("EOL: Windows (CR LF)", 4);
      when SC_EOL_LF =>
        MDI_Child.Status_Bar.Text("EOL: Unix (LF)",       4);
      when others =>
        null;
    end case;
    if MDI_Child.Editor.Get_Overtype then
      MDI_Child.Status_Bar.Text("OVR", 6);
    else
      MDI_Child.Status_Bar.Text("INS", 6);
    end if;
  end Update_status_bar;

  procedure Update_tool_bar (MDI_Child : in out MDI_Child_Type) is
    bar : MDI_Toolbar_Type renames MDI_Child.MDI_Parent.Tool_Bar;
    is_any_selection: constant Boolean :=
      MDI_Child.Editor.Get_Selection_Start < MDI_Child.Editor.Get_Selection_End;
    use LEA_Resource_GUI;
  begin
    bar.Enabled (IDM_Undo, MDI_Child.Editor.Can_Undo);
    bar.Enabled (IDM_Redo, MDI_Child.Editor.Can_Redo);
    bar.Enabled (IDM_Save_File, MDI_Child.Editor.modified);
    bar.Enabled (IDM_Save_All, MDI_Child.save_all_hint);
    bar.Enabled (IDM_Cut, is_any_selection);
    bar.Enabled (IDM_Copy, is_any_selection);
    bar.Enabled (IDM_Paste, MDI_Child.Editor.Can_Paste);
    bar.Enabled (IDM_Indent, True);
    bar.Enabled (IDM_Unindent, True);
    bar.Enabled (IDM_Comment, True);
    bar.Enabled (IDM_Uncomment, True);
    bar.Enabled (IDM_Find, True);
    bar.Enabled (IDM_Show_special_symbols, True);
    bar.Enabled (IDM_Show_indentation_lines, True);
    --  if not MDI_Child.is_closing then
    --    null;  --  bar.Enabled(IDM_ADD_FILES, True);
    --  end if;
  end Update_tool_bar;

  procedure Update_menus (MDI_Child : in out MDI_Child_Type) is
    use LEA_Resource_GUI, GWindows.Menus;
    bool_to_state: constant array (Boolean) of State_Type := (Disabled, Enabled);
    is_any_selection: constant Boolean :=
      MDI_Child.Editor.Get_Selection_Start < MDI_Child.Editor.Get_Selection_End;
  begin
    State (MDI_Child.Menu.Main, Command, IDM_Cut,       bool_to_state (is_any_selection));
    State (MDI_Child.Menu.Main, Command, IDM_Copy,      bool_to_state (is_any_selection));
    State (MDI_Child.Menu.Main, Command, IDM_Paste,     bool_to_state (MDI_Child.Editor.Can_Paste));
    State (MDI_Child.Menu.Main, Command, IDM_Undo,      bool_to_state (MDI_Child.Editor.Can_Undo));
    State (MDI_Child.Menu.Main, Command, IDM_Redo,      bool_to_state (MDI_Child.Editor.Can_Redo));
    State (MDI_Child.Menu.Main, Command, IDM_Save_File, bool_to_state (MDI_Child.Editor.modified));
    State (MDI_Child.Menu.Main, Command, IDM_Save_All,  bool_to_state (MDI_Child.save_all_hint));
  end Update_menus;

  procedure Update_display(
    MDI_Child : in out MDI_Child_Type;
    need   :        Update_need
  )
  is
  pragma Unreferenced (need);
    any_modified: Boolean:= False;
    --
    procedure Check_any_modified (Any_Window : GWindows.Base.Pointer_To_Base_Window_Class)
    --  Enumeration call back to check if any MDI child window has a modified document
    is
    begin
      if Any_Window.all in MDI_Child_Type'Class then
        any_modified := any_modified or MDI_Child_Type(Any_Window.all).Editor.modified;
      end if;
    end Check_any_modified;

  begin
    GWindows.Base.Enumerate_Children (MDI_Client_Window (MDI_Child.MDI_Parent.all).all,
                                      Check_any_modified'Unrestricted_Access);
    MDI_Child.save_all_hint := any_modified;
    if MDI_Child.Editor.modified then
      MDI_Child.Text("* " & GU2G(MDI_Child.Short_Name));
    else
      MDI_Child.Text(GU2G(MDI_Child.Short_Name));
    end if;
    Update_status_bar(MDI_Child);
    Update_tool_bar(MDI_Child);
    Update_menus(MDI_Child);
  end Update_display;

  ---------------
  -- On_Create --
  ---------------

  procedure On_Create (MDI_Child : in out MDI_Child_Type) is
    use GWindows.Base;
  begin
    MDI_Child.Small_Icon("LEA_Doc_Icon_Name");

    --  Filial feelings:
    MDI_Child.MDI_Parent:= MDI_Main_Access(Controlling_Parent(MDI_Child));
    --  No per-child-window option in this app
    --
    --  --  We copy options to child level:
    --  MDI_Child.opt:= MDI_Child.MDI_Parent.opt;

    --  MDI_Child.Tree_Bar_and_List.Create(MDI_Child, Direction => Horizontal);
    --  MDI_Child.Tree_Bar_and_List.Dock(At_Top);
    --
    --    Right panel, with subprogram tree:
    --

    --
    --  *** This will be activated with the Subprogram Tree feature ***
    --
    --  MDI_Child.Subprogram_Panel.Create (MDI_Child, 1,1,20,20);
    --  MDI_Child.Subprogram_Panel.Dock (At_Right);
    --  MDI_Child.Subprogram_Panel.Splitter.Create (MDI_Child.Subprogram_Panel, At_Left);
    --  MDI_Child.Subprogram_Panel.Splitter.MDI_Main := MDI_Child.MDI_Parent;
    --  MDI_Child.Subprogram_Panel.Subprogram_Tree.Create (MDI_Child.Subprogram_Panel, 1,1,20,20, Lines_At_Root => False);
    --  MDI_Child.Subprogram_Panel.Subprogram_Tree.Dock (Fill);

    MDI_Child.Editor.mdi_parent := MDI_Child'Unrestricted_Access;
    MDI_Child.Editor.Create (MDI_Child, 50, 1, 20, 20);  --  Widget starts as a small square...
    MDI_Child.Editor.Dock (Fill);                        --  ...expands into MDI child window.
    MDI_Child.Editor.Set_EOL_Mode (SC_EOL_LF);  --  Windows 10's cmd and notepad accept LF EOL's.

    MDI_Child.Status_Bar.Create (MDI_Child, "No file");
    MDI_Child.Status_Bar.Parts (
        (0 => Status_bar_parts.general_info,      --  General info ("Ada file", ...)
         1 => Status_bar_parts.length_and_lines,  --  Length & lines
         2 => Status_bar_parts.line_and_col,      --  Line / Col
         3 => Status_bar_parts.selection,         --  Selection
         4 => Status_bar_parts.eol_indicator,     --  Unix / Windows / Mac EOLs
         5 => Status_bar_parts.ansi_unicode,      --  ANSI / Unicode
         6 => Status_bar_parts.ins_ovr            --  Ins / Ovr
       )
    );
    MDI_Child.Status_Bar.Dock (At_Bottom);
    MDI_Child.Dock_Children;

    LEA_Resource_GUI.Create_Full_Menu(MDI_Child.Menu);
    --  The list of MDI open children will appear below
    --  the menu indicated with Window_Menu (should be the one with Cascade/Tile/...).
    MDI_Child.MDI_Menu(MDI_Child.Menu.Main, Window_Menu => 7);

    --  Maximize-demaximize (non-maximized case) to avoid invisible windows...
    declare
      memo_unmaximized_children: constant Boolean:=
        not MDI_Child.MDI_Parent.opt.MDI_childen_maximized;
    begin
      if memo_unmaximized_children then
        MDI_Child.MDI_Parent.Freeze;
        MDI_Child.Zoom;
      end if;
      On_Size(MDI_Child,Width(MDI_Child),Height(MDI_Child));
      if memo_unmaximized_children then
        MDI_Child.MDI_Parent.Thaw;  --  Before Zoom, otherwise drawinf is uncomplete.
        MDI_Child.Zoom (False);
        MDI_Child.MDI_Parent.Tool_Bar.Redraw;
      end if;
    end;
    MDI_Child.Update_display(first_display);
    MDI_Child.Accept_File_Drag_And_Drop;
    Ada.Numerics.Float_Random.Reset(MDI_Child.temp_name_gen);
  end On_Create;

  procedure Finish_subwindow_opening (MDI_Child : in out MDI_Child_Type) is
    MDI_Main : MDI_Main_Type renames MDI_Child.MDI_Parent.all;
  begin
    MDI_Main.User_maximize_restore:= True;
    if MDI_Main.opt.MDI_childen_maximized then
      MDI_Child.Zoom;
      MDI_Main.Redraw_all;
    end if;
    --  Show things in the main status bar - effective only after Thaw!
  end Finish_subwindow_opening;

  procedure Save (MDI_Child    : in out MDI_Child_Type;
                  File_Name : in     GWindows.GString)
  is
    written_name: GString_Unbounded:=
      To_GString_Unbounded(File_Name);
    temp_ext : constant GString := ".$$$";
    backup_name : constant GString := File_Name & ".bak";

    use LEA_Common.User_options;
    with_backup : constant Boolean := MDI_Child.MDI_Parent.opt.backup = bak;

    backup_error_1, backup_error_2, backup_error_3 : exception;

    use Ada.Directories;

  begin
    if with_backup then
      written_name := written_name & temp_ext;
    end if;
    --
    MDI_Child.Editor.Save_text (GU2G (written_name));
    --
    if with_backup then
      --  If there was an exception at writing,
      --  the original file is untouched.
      --
      --  !! !! Special characters: MESS with Ada.Directories & UTF,
      --        whatever -> use another tactic...
      --
      --  1/ delete old backup
      if File_Exists (To_UTF_8 (backup_name)) then
        begin
          Delete_File (To_UTF_8 (backup_name));
        exception
          when others =>
            raise backup_error_1;
        end;
      end if;
      --  2/ file -> backup
      if File_Exists (To_UTF_8 (File_Name)) then
        begin
          Rename(
            To_UTF_8 (File_Name),
            To_UTF_8 (backup_name)
          );
        exception
          when others =>
            raise backup_error_2;
        end;
      end if;
      --  3/ new file -> file
      begin
        Rename(
          To_UTF_8 (GU2G(written_name)),
          To_UTF_8 (File_Name)
        );
      exception
        when others =>
          raise backup_error_3;
      end;
    end if;
    --  The eventual startup extra new window is now saved.
    --  So, in any case, we won't close it now on next window open.
    MDI_Child.Extra_first_doc:= False;
    MDI_Child.Update_Common_Menus (File_Name, MDI_Child.Editor.Get_current_line);
    MDI_Child.Editor.Set_Save_Point;
    MDI_Child.Editor.modified:= False;
    MDI_Child.Editor.Set_Read_Only (False);
  exception
    when backup_error_1 =>
      Message_Box (MDI_Child, "Save", "Cannot delete old backup" & NL & "-> " & backup_name, OK_Box, Exclamation_Icon);
    when backup_error_2 =>
      Message_Box (MDI_Child, "Save", "Cannot rename old version to backup" & NL & "-> " & backup_name, OK_Box, Exclamation_Icon);
    when backup_error_3 =>
      Message_Box (MDI_Child, "Save", "Cannot rename new version to actual file" & NL & "-> " & File_Name, OK_Box, Exclamation_Icon);
    when others =>
      Message_Box (MDI_Child, "Save", "Cannot save" & NL & "-> " & File_Name, OK_Box, Exclamation_Icon);
  end Save;

  procedure On_Save (MDI_Child : in out MDI_Child_Type) is
    File_Name : constant GWindows.GString := GU2G (MDI_Child.File_Name);
  begin
    if File_Name = "" or else MDI_Child.Editor.Get_Read_Only then
      MDI_Child.Focus;
      if MDI_Child.Editor.Get_Read_Only then
        Message_Box (MDI_Child, "Save", "This document is read-only" & NL & "You need to save it under another name");
      end if;
      MDI_Child.On_Save_As;
    else
      Save (MDI_Child, File_Name);
    end if;
  end On_Save;

  function Is_file_saved (MDI_Child : in MDI_Child_Type) return Boolean is
  begin
    return not MDI_Child.Editor.modified;
  end Is_file_saved;

  ----------------
  -- On_Save_As --
  ----------------

  procedure On_Save_As (MDI_Child : in out MDI_Child_Type)
  is
    New_File_Name : GWindows.GString_Unbounded;
    File_Title    : GWindows.GString_Unbounded;
    Success       : Boolean;
  begin
    if MDI_Child.File_Name = "" then
      New_File_Name := MDI_Child.Short_Name;  --  Try with short name (window title).
    else
      New_File_Name := MDI_Child.File_Name;  --  Tentative name is current file name.
    end if;
    GWindows.Common_Dialogs.Save_File (
      MDI_Child,
      "Save file as...",
      New_File_Name,
      MDI_Child.MDI_Parent.text_files_filters,
      ".ada",
      File_Title,
      Success
    );
    if not Success then
      return;
    end if;
    if File_Exists(To_UTF_8(GU2G(New_File_Name))) then
      if Message_Box (
        MDI_Child,
        "Save as",
        "The file " & GU2G (New_File_Name) & " already exists. Replace ?",
        Yes_No_Box,
        Question_Icon
      ) = No
      then
        return;
      end if;
    end if;

    Save (MDI_Child, GU2G(New_File_Name));
    MDI_Child.File_Name := New_File_Name;
    MDI_Child.Text(GU2G(File_Title));
    MDI_Child.Short_Name:= File_Title;
    MDI_Child.Update_Common_Menus(GU2G(New_File_Name), MDI_Child.Editor.Get_current_line);
    MDI_Child.Editor.syntax_kind :=
      LEA_Common.Syntax.Guess_syntax (
        GU2G (MDI_Child.File_Name),
        GU2G (MDI_Child.MDI_Parent.opt.ada_files_filter)
      );
    MDI_Child.Editor.Set_Scintilla_Syntax;
  end On_Save_As;

  procedure On_Save_All (MDI_Child : in out MDI_Child_Type) is
    --
    procedure Save_any_modified (Any_Window : GWindows.Base.Pointer_To_Base_Window_Class)
    is
    begin
      if Any_Window.all in MDI_Child_Type'Class then
        declare
          one_child: MDI_Child_Type renames MDI_Child_Type(Any_Window.all);
        begin
          if not one_child.Is_file_saved then
            one_child.On_Save;
          end if;
        end;
      end if;
    end Save_any_modified;
    --
  begin
    GWindows.Base.Enumerate_Children (MDI_Client_Window (MDI_Child.MDI_Parent.all).all,
                                      Save_any_modified'Unrestricted_Access);
  end On_Save_All;

  procedure On_File_Drop (MDI_Child  : in out MDI_Child_Type;
                          File_Names : in     GWindows.Windows.Array_Of_File_Names)
  is
    parent : MDI_Main_Access;
  begin
    MDI_Child.Focus;
    --  We save the parent access since this MDI_Child may be already closed
    --  when i > File_Names'First if MDI_Child is was temporary MS-Office-like
    --  blank window - See procedure Close_extra_first_child.
    parent:= MDI_Child.MDI_Parent;
    for i in File_Names'Range loop
      Open_Child_Window_And_Load(parent.all, File_Names(i));
    end loop;
  end On_File_Drop;

  --  This will update File menu of parent, itself, and all brothers and sisters
  procedure Update_Common_Menus(MDI_Child : MDI_Child_Type;
    top_entry_name : GString := "";
    top_entry_line : Natural := 0    --  When unknown, 0; otherwise: last visited line
  )
  is
  begin
    Update_Common_Menus( MDI_Child.MDI_Parent.all, top_entry_name, top_entry_line );
  end Update_Common_Menus;

  procedure On_Size (MDI_Child : in out MDI_Child_Type;
                     Width  : in     Integer;
                     Height : in     Integer)
  is
  begin
    if MDI_Child.MDI_Parent.User_maximize_restore then
      MDI_Child.MDI_Parent.opt.MDI_childen_maximized := Zoom (MDI_Child);
    end if;
    Dock_Children (MDI_Child);
  end On_Size;

  procedure Build_as_Main (MDI_Child : in out MDI_Child_Type) is
    use HAC_Sys.Defs, Messages;
    MDI_Main : MDI_Main_Type renames MDI_Child.MDI_Parent.all;
    ml : Message_List_Type renames MDI_Main.Message_Panel.Message_List;
    message_count, err_count : Natural := 0;
    --
    procedure LEA_HAC_Build_Error_Feedback (diagnostic : Diagnostic_Kit) is
      use Ada.Characters.Handling, Ada.Strings, Ada.Strings.Wide_Fixed;
      msg_up : String := To_String (diagnostic.message);
      has_dark_background : constant Boolean := MDI_Main.opt.color_theme = Dark_side;
    begin
      msg_up (msg_up'First) := To_Upper (msg_up (msg_up'First));
      ml.Insert_Item (
        Trim (Integer'Wide_Image (diagnostic.line), Left),
        message_count,
        Icon => Wrench_Icon (diagnostic.repair_kind /= none, has_dark_background)
      );
      --  Here we set a payload in order to get the source file and position
      --  when selecting a row in the error / warnings message list.
      ml.Item_Data (
        message_count,
        new Diagnostic_Kit'(diagnostic)  --  Copy diagnostic into a new heap allocated object.
      );
      ml.Set_Sub_Item (S2G (msg_up), message_count, 1);
      message_count := message_count + 1;
      err_count := err_count + 1;
    end LEA_HAC_Build_Error_Feedback;
    --
    procedure LEA_HAC_Build_Feedback (message : String) is
    begin
      ml.Insert_Item ("    ", message_count);
      ml.Set_Sub_Item (S2G (message), message_count, 1);
      message_count := message_count + 1;
    end LEA_HAC_Build_Feedback;
    --
    use_editor_stream : constant Boolean := True;
    --  ^ So far we don't set a main file name elsewhere, so we
    --    can always use the editor data as a stream.
    use HAC_Sys.Builder,
        Ada.Calendar, Ada.Directories, Ada.Strings, Ada.Strings.Wide_Fixed, Ada.Text_IO;
    f : Ada.Text_IO.File_Type;
    file_name  : constant String := G2S (GU2G (MDI_Child.File_Name));
    short_name : constant String := G2S (GU2G (MDI_Child.Short_Name));
    shebang_offset : Natural;
    t1, t2 : Time;
    --
    function Best_Name return String is
    begin
      if file_name = "" then  --  For example, an unsaved template.
        return short_name;
      else
        return file_name;
      end if;
    end Best_Name;
    --
  begin
    case MDI_Child.MDI_Parent.opt.toolset is
      when HAC_mode =>
        if use_editor_stream then
          --  We connect the main editor input stream to this window's editor.
          MDI_Child.MDI_Parent.current_editor_stream.Reset (MDI_Child.Editor, shebang_offset);
          Set_Main_Source_Stream (
            MDI_Child.BD,
            MDI_Child.MDI_Parent.current_editor_stream'Access,
            Best_Name, shebang_offset);
        else
          --  In case the file is not open in an editor window in LEA,
          --  we use Stream_IO.
          Open (f, In_File, file_name);
          Skip_Shebang (f, shebang_offset);
          Set_Main_Source_Stream (MDI_Child.BD, Text_Streams.Stream (f), Best_Name, shebang_offset);
        end if;
        --
        --  We switch the current directory in order to compile other units that
        --  may reside in the same directory as main.
        --  To do: support project files with source paths.
        --
        begin
          Set_Directory (Containing_Directory (file_name));
        exception
          when Ada.Directories.Name_Error => null;  --  Could be a sample, an unsaved file, ...
        end;
        ml.Clear;
        ml.Set_Column ("Line",     0, 60);
        ml.Set_Column ("Message",  1, 800);
        Set_Message_Feedbacks
          (MDI_Child.BD,
           (pipe         => LEA_HAC_Build_Error_Feedback'Unrestricted_Access,
            progress     => LEA_HAC_Build_Feedback'Unrestricted_Access,
            detail_level => 1));
        t1 := Clock;
        Build_Main (MDI_Child.BD);
        t2 := Clock;
        if not use_editor_stream then
          Close (f);
        end if;
        Set_Message_Feedbacks (MDI_Child.BD, HAC_Sys.Co_Defs.default_trace);
        --  Here we have a single-unit build, from the current child window:
        MDI_Main.build_successful := Build_Successful (MDI_Child.BD);
        if err_count = 0 then
          ml.Insert_Item ("", message_count);
          ml.Set_Sub_Item
            ("Build finished in" &
             Duration'Wide_Image (t2 - t1) &
             " seconds." &
             Integer'Wide_Image (MDI_Child.BD.Total_Compiled_Lines) &
             " lines compiled. No error, no warning",
             message_count, 1);
        else
          --  Jump on first error
          for Index in 0 .. ml.Item_Count - 1 loop
            if Trim (ml.Text (Index, 0), Both) /= "" then
              ml.Selected (Index, True);
              ml.Message_line_action (real_click => False);
              exit;
            end if;
          end loop;
        end if;
      when GNAT_mode =>
        null;
    end case;
  end Build_as_Main;

  procedure Build (MDI_Child : in out MDI_Child_Type) is
  begin
    case MDI_Child.MDI_Parent.opt.toolset is
      when HAC_mode =>
        case MDI_Child.MDI_Parent.opt.view_mode is
          when Notepad =>
            MDI_Child.Build_as_Main;
          when Studio =>
            null;
            --  !!  In project/studio mode, we will build
            --      project's main, from editors or files
        end case;
      when GNAT_mode =>
        null;
    end case;
  end Build;

  procedure Build_and_run (MDI_Child : in out MDI_Child_Type) is
  begin
    MDI_Child.Build;
    if MDI_Child.MDI_Parent.build_successful then
      Run_Windowed (MDI_Child);
    end if;
  end Build_and_run;

  procedure On_Menu_Select (
        MDI_Child : in out MDI_Child_Type;
        Item      : in     Integer
  )
  is
    use LEA_Resource_GUI;
  begin
    if MDI_Child.Editor.document_kind /= editable_text then
      --  Call parent method
      GWindows.Windows.Window_Type (MDI_Child).On_Menu_Select (Item);
      return;
    end if;
    --
    case Item is
      when IDM_Save_File =>
        MDI_Child.On_Save;
      when IDM_Save_As =>
        MDI_Child.On_Save_As;
      when IDM_Save_All =>
        MDI_Child.On_Save_All;
      when IDM_Close =>
        MDI_Child.Close;
      when IDM_Undo =>
        MDI_Child.Editor.Undo;
        MDI_Child.Update_display(toolbar_and_menu);  --  Eventually disable Undo if no more available
      when IDM_Redo =>
        MDI_Child.Editor.Redo;
        MDI_Child.Update_display(toolbar_and_menu);  --  Eventually disable Redo if no more available
      when IDM_Cut =>           MDI_Child.Editor.Cut;
      when IDM_Copy =>          MDI_Child.Editor.Copy;
      when IDM_Paste =>         MDI_Child.Editor.Paste;
      when IDM_Select_all =>    MDI_Child.Editor.Select_All;
      when IDM_Indent =>
        MDI_Child.Editor.Set_Tab_Width (MDI_Child.MDI_Parent.opt.indentation);
        MDI_Child.Editor.Tab;
        MDI_Child.Editor.Set_Tab_Width (MDI_Child.MDI_Parent.opt.tab_width);
      when IDM_Unindent =>
        MDI_Child.Editor.Set_Tab_Width (MDI_Child.MDI_Parent.opt.indentation);
        MDI_Child.Editor.Back_Tab;
        MDI_Child.Editor.Set_Tab_Width (MDI_Child.MDI_Parent.opt.tab_width);
      when IDM_Comment =>       MDI_Child.Editor.Selection_comment;
      when IDM_Uncomment =>     MDI_Child.Editor.Selection_uncomment;
      when IDM_Find =>          MDI_Child.Show_Search_Box;
      when IDM_Find_Next =>
        --  If F3 is pressed or "Find next" menu entry is selected
        --  while search box is focused, we need to update the drop-down list(s).
        Search_box.Update_drop_downs (MDI_Child.MDI_Parent.Search_box);
        MDI_Child.Editor.Search (find_next);
      when IDM_Find_Previous =>
        Search_box.Update_drop_downs (MDI_Child.MDI_Parent.Search_box);
        MDI_Child.Editor.Search (find_previous);
      when IDM_Go_to_line =>
        Modal_Dialogs.Do_Go_to_Line (MDI_Child);
      when IDM_Toggle_bookmark =>
        MDI_Child.Editor.Bookmark_toggle (MDI_Child.Editor.Get_current_line);
      when IDM_Next_bookmark =>
        MDI_Child.Editor.Bookmark_next;
      when IDM_Previous_bookmark =>
        MDI_Child.Editor.Bookmark_previous;
      --  Compile / Build actions
      when IDM_Compile_single =>  MDI_Child.Build_as_Main;
      when IDM_Build          =>  MDI_Child.Build;
      when IDM_Build_and_run  =>  MDI_Child.Build_and_run;
      --
      when IDM_Show_special_symbols =>
        LEA_Common.User_options.Toggle_show_special (MDI_Child.MDI_Parent.opt);
        Options.Apply_Main_Options (MDI_Child.MDI_Parent.all);
      when IDM_Show_indentation_lines =>
        MDI_Child.MDI_Parent.opt.show_indent :=
          not MDI_Child.MDI_Parent.opt.show_indent;
        Options.Apply_Main_Options (MDI_Child.MDI_Parent.all);
      when IDM_Duplicate =>
        MDI_Child.Editor.Duplicate;
      when others =>
        --  Call parent method
        GWindows.Windows.Window_Type (MDI_Child).On_Menu_Select (Item);
    end case;
  end On_Menu_Select;

  overriding procedure On_Focus (MDI_Child : in out MDI_Child_Type) is
  begin
    Update_display(MDI_Child, toolbar_and_menu);
    MDI_Child.Editor.Focus;
  end On_Focus;

  overriding procedure On_Close (MDI_Child    : in out MDI_Child_Type;
                      Can_Close :    out Boolean)
  is
    use LEA_Resource_GUI;
    bar : MDI_Toolbar_Type renames MDI_Child.MDI_Parent.Tool_Bar;
  begin
    Can_Close:= True;
    if Is_file_saved(MDI_Child) then
      MDI_Child.Update_Common_Menus(GU2G(MDI_Child.File_Name), MDI_Child.Editor.Get_current_line);
    else -- This happens only for documents that may stay in an unsaved state.
      loop
        case Message_Box
               (MDI_Child,
                "Close file", -- sheet, picture, ...
                "Do you want to save the changes you made to """ &
                GU2G(MDI_Child.Short_Name) & """ ?",
                Yes_No_Cancel_Box,
                Question_Icon)
        is
          when Yes    => On_Save(MDI_Child);
                         exit when Is_file_saved(MDI_Child);
          when No     => exit;
          when Cancel => MDI_Child.MDI_Parent.Success_in_enumerated_close:= False;
                         Can_Close:= False;
                         exit;
          when others => null;
        end case;
      end loop;
    end if;
    if Can_Close then
      --  !! Empty the editor's memory if needed
      --
      --  No per-child-window option in this app
      --  -- Pass view mode and the tree width portion to parent,
      --  -- this will memorize choice of last closed window.
      --  MDI_Child.MDI_Parent.opt.view_mode:= MDI_Child.opt.view_mode;
      --
      --  !!  Memorize_splitter(MDI_Child);
      --  MDI_Child.MDI_Parent.opt.tree_portion:= MDI_Child.opt.tree_portion;
      --
      --  For the case there is no more child window, disable toolbar items.
      --  This action is reversed as soon as another child window is focused.
      bar.Enabled (IDM_Save_File, False);
      bar.Enabled (IDM_Save_All, False);
      bar.Enabled (IDM_Undo, False);
      bar.Enabled (IDM_Redo, False);
      bar.Enabled (IDM_Cut, False);
      bar.Enabled (IDM_Copy, False);
      bar.Enabled (IDM_Paste, False);
      bar.Enabled (IDM_Comment, False);
      bar.Enabled (IDM_Uncomment, False);
      bar.Enabled (IDM_Indent, False);
      bar.Enabled (IDM_Unindent, False);
      bar.Enabled (IDM_Find, False);
      bar.Enabled (IDM_Show_special_symbols, False);
      bar.Enabled (IDM_Show_indentation_lines, False);
      MDI_Child.is_closing:= True;
    end if;
  end On_Close;

  procedure Show_Search_Box (MDI_Child : in out MDI_Child_Type) is
    sel_a, sel_z : Scintilla.Position;
  begin
    sel_a := MDI_Child.Editor.Get_Selection_Start;
    sel_z := MDI_Child.Editor.Get_Selection_End;
    if sel_z > sel_a then
      --  Goodie: put the selected text into the "find" box.
      MDI_Child.MDI_Parent.Search_box.Find_box.Text (MDI_Child.Editor.Get_Text_Range (sel_a, sel_z));
    end if;
    MDI_Child.MDI_Parent.Search_box.Show;
    MDI_Child.MDI_Parent.Search_box.Find_box.Focus;
  end Show_Search_Box;

end LEA_GWin.MDI_Child;
