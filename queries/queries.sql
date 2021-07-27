create view trends.docs as
SELECT
  extract(date from timestamp) as dt,
  ml.ngrams(
    split(
      regexp_replace(
        regexp_replace(
          lower(text),
          r"[^a-z0-9\s]",
          ""
        ),
        r"\s+",
        " "
      ),
      " "
    ),
    [1, 3],
    " "
  ) as phrase_arr
FROM `bigquery-public-data.hacker_news.full`;

create table trends.phrase_cnts_raw as
select
  phrase,
  count(1) as phrase_cnt,
  dt
from trends.docs, unnest(docs.phrase_arr) as phrase
group by
  phrase,
  dt;

create table trends.doc_cnts as
select
  count(1) doc_cnt,
  dt
from trends.docs
group by
   dt;

create table trends.phrase_cnts as
select
  phrase,
  phrase_cnt,
  doc_cnt,
  dt
from trends.phrase_cnts_raw
join trends.doc_cnts using(dt);

create table trends.phrase_agg as
select
  phrase,
  phrase_cnt,
  doc_cnt,
  sum(phrase_cnt) over w /sum(doc_cnt) over w as phrase_freq_avg,
  pow(pow(phrase_cnt/doc_cnt - sum(phrase_cnt) over w /sum(doc_cnt) over w, 2) / sum(doc_cnt) over w, 0.5) as phrase_freq_stddev,
  dt
from trends.phrase_cnts
group by
  phrase,
  phrase_cnt,
  doc_cnt,
  dt
window w as (
  partition by phrase
  order by dt
  rows between 30 preceding and current row
);

create table trends.phrase_final as
select
  phrase,
  phrase_cnt,
  doc_cnt,
  phrase_cnt/doc_cnt as phrase_freq,
  phrase_freq_avg,
  phrase_freq_stddev,
  safe_divide(phrase_cnt/doc_cnt - phrase_freq_avg, phrase_freq_stddev) as z_score,
  dt
from trends.phrase_agg;

