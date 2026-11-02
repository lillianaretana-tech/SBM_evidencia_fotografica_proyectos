-- Aplicado en Supabase mediante migración evidence_private_feedback.
-- Referencia para instalación nueva; no ejecutar nuevamente sobre la tabla existente.
create table public.sbm_evidence_feedback (
id uuid primary key default gen_random_uuid(),
user_id uuid not null default auth.uid() references auth.users(id),
person_id uuid references public.sbm_evidence_people(id),
project_id uuid references public.sbm_portal_projects(id),
sender_name text not null check(length(btrim(sender_name)) between 1 and 200),
category text not null check(category in ('comentario','sugerencia','problema')),
message text not null check(length(btrim(message)) between 3 and 3000),
status text not null default 'pendiente' check(status in ('pendiente','en_revision','atendido')),
response text not null default '' check(length(response)<=3000),
created_at timestamptz not null default now(),
responded_at timestamptz,
responded_by uuid references auth.users(id)
);
alter table public.sbm_evidence_feedback enable row level security;
revoke all on public.sbm_evidence_feedback from anon,authenticated;
grant select on public.sbm_evidence_feedback to authenticated;
grant insert(user_id,person_id,project_id,sender_name,category,message) on public.sbm_evidence_feedback to authenticated;
grant update(status,response,responded_at,responded_by) on public.sbm_evidence_feedback to authenticated;
create policy feedback_read on public.sbm_evidence_feedback for select to authenticated using(user_id=(select auth.uid()) or (select public.sbm_portal_is_admin()));
create policy feedback_send on public.sbm_evidence_feedback for insert to authenticated with check(
 user_id=(select auth.uid()) and (
 (person_id is not null and exists(select 1 from public.sbm_evidence_people p where p.id=person_id and p.project_id=sbm_evidence_feedback.project_id and p.auth_user_id=(select auth.uid()) and p.active and p.display_name=sender_name))
 or (person_id is null and ((select public.sbm_portal_is_admin()) or exists(select 1 from public.sbm_evidence_supervisors s where s.user_id=(select auth.uid()) and s.project_id=sbm_evidence_feedback.project_id)))
 ));
create policy feedback_manage on public.sbm_evidence_feedback for update to authenticated using((select public.sbm_portal_is_admin())) with check((select public.sbm_portal_is_admin()) and responded_by=(select auth.uid()));
create index feedback_user_created on public.sbm_evidence_feedback(user_id,created_at desc);
create index feedback_created on public.sbm_evidence_feedback(created_at desc);
create index feedback_project on public.sbm_evidence_feedback(project_id);
create index feedback_person on public.sbm_evidence_feedback(person_id);
create index feedback_responder on public.sbm_evidence_feedback(responded_by);
notify pgrst,'reload schema';