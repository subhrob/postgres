--
-- PARALLEL
--

create or replace function parallel_restricted(int) returns int as $$
begin
  perform * from pg_stat_activity where client_port is null;
  if (found) then
    raise 'parallel restricted function run in worker';
  end if;
  return $1;
end$$ language plpgsql parallel restricted;

-- Serializable isolation would disable parallel query, so explicitly use an
-- arbitrary other level.
begin isolation level repeatable read;

-- setup parallel test
set parallel_setup_cost=0;
set parallel_tuple_cost=0;
set max_parallel_workers_per_gather=4;

explain (costs off)
  select count(*) from a_star;
select count(*) from a_star;

-- test that parallel_restricted function doesn't run in worker
alter table tenk1 set (parallel_workers = 4);
explain (verbose, costs off)
select parallel_restricted(unique1) from tenk1
  where stringu1 = 'GRAAAA' order by 1;
select parallel_restricted(unique1) from tenk1
  where stringu1 = 'GRAAAA' order by 1;

set force_parallel_mode=1;

explain (costs off)
  select stringu1::int2 from tenk1 where unique1 = 1;

do $$begin
  -- Provoke error in worker.  The original message CONTEXT contains a worker
  -- PID that must be hidden in the test output.
  perform stringu1::int2 from tenk1 where unique1 = 1;
  exception
	when others then
		raise 'SQLERRM: %', sqlerrm;
end$$;

rollback;
