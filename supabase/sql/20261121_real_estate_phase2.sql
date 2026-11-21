-- 不動産（自宅）管理 第2段階: ローン残高の自動計算
-- Supabase ダッシュボードの SQL Editor で1回だけ実行する。
--
-- current_loan_balance を「loan_balance_as_of の月の返済後の残高（起点）」として扱い、
-- それ以降の月の残高はアプリが金利と返済額から計算する。
-- 既存の行は、最後に保存した月（updated_at の月、無ければローン開始月）を起点にする。

alter table public.real_estate_details
  add column if not exists loan_balance_as_of date;

update public.real_estate_details
set loan_balance_as_of = date_trunc('month', coalesce(updated_at, loan_start_date::timestamp))::date
where loan_balance_as_of is null;

comment on column public.real_estate_details.loan_balance_as_of is
  'current_loan_balance がどの月の返済後の残高か（月初の日付）。この月より後の残高はアプリが自動計算する';
