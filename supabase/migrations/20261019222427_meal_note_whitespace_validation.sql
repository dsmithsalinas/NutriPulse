-- Match app validation for line breaks/tabs as well as spaces.
alter table public.meal_notes add constraint meal_notes_nonblank_body
    check (body !~ '^[[:space:]]*$');
