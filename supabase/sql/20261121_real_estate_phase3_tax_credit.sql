-- 不動産（自宅）管理: 住宅ローン控除の見込み
-- Supabase ダッシュボードの SQL Editor で1回だけ実行する。
-- 入居年が空の行は控除を計算しない（これまでと同じ表示）。

alter table public.real_estate_details
  add column if not exists tax_credit_move_in_year integer,
  add column if not exists tax_credit_rate_percent numeric not null default 0.7
    check (tax_credit_rate_percent >= 0),
  add column if not exists tax_credit_years integer not null default 13
    check (tax_credit_years >= 0),
  add column if not exists tax_credit_loan_limit bigint not null default 0
    check (tax_credit_loan_limit >= 0),
  add column if not exists tax_credit_annual_cap bigint not null default 0
    check (tax_credit_annual_cap >= 0);

-- 取得原価に入れない諸費用（ローン手数料・抵当権設定登記・修繕積立基金・延長保証など）の記録
alter table public.real_estate_details
  add column if not exists other_initial_costs bigint not null default 0
    check (other_initial_costs >= 0),
  add column if not exists other_initial_costs_memo text not null default '';

comment on column public.real_estate_details.other_initial_costs is '取得原価に入れない諸費用（自分が払った分）。記録用で計算には使わない';
comment on column public.real_estate_details.other_initial_costs_memo is '取得原価に入れない諸費用の内訳メモ';

comment on column public.real_estate_details.tax_credit_move_in_year is '住宅ローン控除: 入居年（空なら計算しない）';
comment on column public.real_estate_details.tax_credit_rate_percent is '住宅ローン控除: 控除率（%）';
comment on column public.real_estate_details.tax_credit_years is '住宅ローン控除: 控除期間（年）';
comment on column public.real_estate_details.tax_credit_loan_limit is '住宅ローン控除: 借入限度額（自分の分。0 なら上限なし）';
comment on column public.real_estate_details.tax_credit_annual_cap is '住宅ローン控除: 1年の控除の上限（所得税＋住民税から引ける額。0 なら上限なし）';
