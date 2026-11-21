-- 不動産（自宅）管理 第1段階: 持分・土地建物の内訳・取得原価に入れる初期費用
-- Supabase ダッシュボードの SQL Editor で1回だけ実行する。
-- 既存の行は「持分 1/1・内訳なし・初期費用 0」になり、これまでと同じ計算結果になる。

alter table public.real_estate_details
  add column if not exists ownership_share_numerator integer not null default 1
    check (ownership_share_numerator > 0),
  add column if not exists ownership_share_denominator integer not null default 1
    check (ownership_share_denominator > 0),
  add column if not exists land_price bigint not null default 0
    check (land_price >= 0),
  add column if not exists building_price bigint not null default 0
    check (building_price >= 0),
  add column if not exists capitalized_initial_costs bigint not null default 0
    check (capitalized_initial_costs >= 0);

comment on column public.real_estate_details.ownership_share_numerator is '自分の持分（分子）。登記上の持分';
comment on column public.real_estate_details.ownership_share_denominator is '自分の持分（分母）';
comment on column public.real_estate_details.land_price is '物件全体の土地価格（内訳）';
comment on column public.real_estate_details.building_price is '物件全体の建物価格（内訳）';
comment on column public.real_estate_details.capitalized_initial_costs is '自分が払った初期費用のうち取得原価に入れる分（仲介手数料・登記費用・不動産取得税・印紙税）';
