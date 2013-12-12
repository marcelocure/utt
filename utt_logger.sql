create or replace package utt_logger is
--Author: Marcelo Cure
  type logger is record (id number,
                         test varchar2(32),
                         result varchar2(400));
  type statistics is record (total_tests number,
                             passed_tests number,
                             failed_tests number);
  type t_logger is table of logger index by binary_integer;
  tb_logger t_logger;
  v_statistics statistics;
  v_idx number := 0;
  procedure add(p_result in varchar2, p_procedure in varchar2);
  procedure print_logger;
end utt_logger;
/
create or replace package body utt_logger is
  procedure clean_cache is
  begin
    tb_logger.delete;
    v_idx := 0;
    v_statistics.failed_tests := 0;
    v_statistics.passed_tests := 0;
    v_statistics.total_tests := 0;
  end;

  procedure increment_id is
  begin
    v_idx := v_idx + 1;
  end;

  procedure add_statistics is
  begin
    if tb_logger(v_idx).result like 'failed%' then
      v_statistics.failed_tests := v_statistics.failed_tests + 1;
    else
      v_statistics.passed_tests := v_statistics.passed_tests + 1;
    end if;
    v_statistics.total_tests := v_statistics.total_tests + 1;
  end;

  procedure add(p_result in varchar2, p_procedure in varchar2) is
  begin
    increment_id;
    tb_logger(v_idx).id := v_idx;
    tb_logger(v_idx).test := p_procedure;
    tb_logger(v_idx).result := p_result;
    add_statistics;
  end;

  procedure print_statistics is
  begin
    dbms_output.put_line('');
    dbms_output.put_line('### Statistics');
    dbms_output.put_line('Total passed tests: '||v_statistics.passed_tests);
    dbms_output.put_line('Total failed tests: '||v_statistics.failed_tests);
    dbms_output.put_line('-----------------------');
    dbms_output.put_line('Total tests: '||v_statistics.total_tests);
  end;

  procedure print_results is
  begin
    dbms_output.put_line('### Running tests');
    dbms_output.put_line('');
    dbms_output.put_line('   '||rpad('Procedure',40,' ') || 'Result');
    dbms_output.put_line('   '||rpad('-',46,'-'));
    for i in tb_logger.first .. tb_logger.last loop
      dbms_output.put_line('   '||rpad(tb_logger(i).test,40,' ') || tb_logger(i).result);
    end loop;
  end;

  procedure print_logger is
  begin
    print_results;
    print_statistics;
    clean_cache;
  end;

begin
  dbms_output.enable(buffer_size => null);
  clean_cache;
end utt_logger;
/
