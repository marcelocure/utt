PROMPT
PROMPT Installation started
PROMPT

create or replace package utt_logger is
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
  procedure add(p_result in varchar2);
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
  
  procedure add(p_result in varchar2) is
  begin
    increment_id;
    tb_logger(v_idx).id := v_idx;
    tb_logger(v_idx).test := utt.curr_procedure;
    tb_logger(v_idx).result := p_result;
    add_statistics;
  end;
  
  procedure print_statistics is
  begin
    dbms_output.put_line('');
    dbms_output.put_line('### Statistics');
    dbms_output.put_line('Total passed tests: '||v_statistics.passed_tests);
    dbms_output.put_line('Total failed tests: '||v_statistics.failed_tests);
    dbms_output.put_line('');
    dbms_output.put_line('Total tests: '||v_statistics.total_tests);
  end;
  
  procedure print_results is
  begin
    dbms_output.put_line('### Running tests for '||utt.curr_package);
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

create or replace package utt is
  e_many_columns exception;
  curr_procedure varchar2(32);
  curr_package varchar2(32);
  procedure run_all_tests(p_package in varchar2, p_owner in varchar2);
  procedure run_single_test(p_package in varchar2, p_test in varchar2);
  procedure assert_equals(p_expected in varchar2, p_actual in varchar2);
  procedure assert_not_equals(p_expected in varchar2, p_actual in varchar2);
  procedure assert_true(p_actual in boolean);
  procedure assert_false(p_actual in boolean);
  procedure assert_null(p_actual in varchar2);
  procedure assert_not_null(p_actual in varchar2);
  procedure assert_object_exists(p_object_name in varchar2);
  procedure assert_object_not_exists(p_object_name in varchar2);
  procedure assert_query_same_countrows(p_query1 in varchar2, p_query2 in varchar2);
  procedure assert_query_diff_countrows(p_query1 in varchar2, p_query2 in varchar2);
  procedure assert_query_same_value(p_query1 in varchar2, p_query2 in varchar2);
  procedure assert_query_diff_value(p_query1 in varchar2, p_query2 in varchar2);
  procedure assert_dml_rowcount(p_expected in number);
end utt;
/

create or replace package body utt is
  procedure execute_plsql(p_plsql in varchar2) is
  begin
    execute immediate p_plsql;
  end;
  
  procedure run_all_tests(p_package in varchar2, p_owner in varchar2) is
    cursor c_tests is
      select procedure_name
      from all_procedures
      where object_name = upper(p_package)
        and owner = upper(p_owner)
        and procedure_name like 'T_%';
    v_model varchar2(200) := 'begin '||p_owner||'.'||p_package||'.<PROCEDURE>; end;';
  begin
    curr_package := p_package;
    open c_tests;
    loop
      fetch c_tests into curr_procedure ;
      exit when c_tests%notfound;
      execute_plsql(replace(v_model,'<PROCEDURE>',curr_procedure));
    end loop;
    close c_tests;
    utt_logger.print_logger;
  exception
    when others then
      dbms_output.put_line(sqlerrm);
      dbms_output.put_line(dbms_utility.format_error_backtrace);
  end;
  
  procedure run_single_test(p_package in varchar2, p_test in varchar2) is
    v_model varchar2(200) := 'begin '||p_package||'.'||p_test||'; end;';
  begin
    curr_package := p_package;
    execute_plsql(v_model);
  end;
  
  function build_failed_message(p_expected in varchar2, p_actual in varchar2) return varchar2 is
  begin
    return 'failed: expected "'||p_expected||'" but got "'||p_actual||'"';
  end;  

  function is_select_clausule_invalid(p_without_from in varchar2) return boolean is
  begin
    if p_without_from like '%*%' or instr(p_without_from,',') > 0 then
      return true;
    end if;
    return false;
  end;
  
  function validate_query(p_query in varchar2) return boolean is
    v_without_select varchar2(100) := substr(p_query,instr(p_query,' '));
    v_without_from varchar2(100) := substr(v_without_select,1,instr(v_without_select,'from')-1);
  begin
    if is_select_clausule_invalid(v_without_from) then
      return false;
    end if;
    return true;
  end;
  
  procedure assert_equals(p_expected in varchar2, p_actual in varchar2) is
  begin
    if p_expected = p_actual then
      utt_logger.add(p_result => 'passed');
    else
      utt_logger.add(p_result => build_failed_message(p_expected,p_actual));
    end if;
  end;
  
  procedure assert_not_equals(p_expected in varchar2, p_actual in varchar2) is
  begin
    if p_expected != p_actual then
      utt_logger.add(p_result => 'passed');
    else
      utt_logger.add(build_failed_message(p_expected,p_actual));
    end if;
  end;

  procedure assert_true(p_actual in boolean) is
  begin
    if p_actual then
      utt_logger.add(p_result => 'passed');
    else
      utt_logger.add(build_failed_message('true','false'));
    end if;
  end;

  procedure assert_false(p_actual in boolean) is
  begin
    if not p_actual then
      utt_logger.add(p_result => 'passed');
    else
      utt_logger.add(build_failed_message('false','true'));
    end if;
  end;
  
  procedure assert_null(p_actual in varchar2) is
  begin
    if p_actual is null then
      utt_logger.add(p_result => 'passed');
    else
      utt_logger.add(build_failed_message('not null',p_actual));
    end if;
  end;
  
  procedure assert_not_null(p_actual in varchar2) is
  begin
    if p_actual is not null then
      utt_logger.add(p_result => 'passed');
    else
      utt_logger.add(build_failed_message('null',p_actual));
    end if;
  end;
  
  procedure assert_object_exists(p_object_name in varchar2) is
    cursor c_get_object is
      select object_name
      from all_objects
      where object_name = upper(p_object_name);
    v_object_name varchar2(32) := 'object doesn''t exist';
  begin
    open c_get_object;
    fetch c_get_object into v_object_name;
    close c_get_object;
    
    if upper(p_object_name) = v_object_name then
      utt_logger.add(p_result => 'passed');
    else
      utt_logger.add(build_failed_message(upper(p_object_name),v_object_name));
    end if;
  end;
  
  procedure assert_object_not_exists(p_object_name in varchar2) is
    cursor c_get_object is
      select object_name
      from all_objects
      where object_name = upper(p_object_name);
    v_object_name varchar2(32) := 'object doesn''t exist';
  begin
    open c_get_object;
    fetch c_get_object into v_object_name;
    close c_get_object;
    
    if v_object_name = 'object doesn''t exist' then
      utt_logger.add(p_result => 'passed');
    else
      utt_logger.add(build_failed_message('NONE',v_object_name));
    end if;
  end;
  
  procedure assert_query_same_countrows(p_query1 in varchar2, p_query2 in varchar2) is
    v_query1 varchar2(4000) := 'select count(1) from ('||p_query1||')';
    v_query2 varchar2(4000) := 'select count(1) from ('||p_query2||')';
    v_count_rows_query1 number;
    v_count_rows_query2 number;
  begin
    execute immediate v_query1 into v_count_rows_query1;
    execute immediate v_query2 into v_count_rows_query2;
    
    if v_count_rows_query1 = v_count_rows_query2 then
      utt_logger.add(p_result => 'passed');
    else
      utt_logger.add('failed query 1 returns '||v_count_rows_query1||' rows and query2 returns '||v_count_rows_query2||' rows');
    end if;
  end;
  
  procedure assert_query_diff_countrows(p_query1 in varchar2, p_query2 in varchar2) is
    v_query1 varchar2(4000) := 'select count(1) from ('||p_query1||')';
    v_query2 varchar2(4000) := 'select count(1) from ('||p_query2||')';
    v_count_rows_query1 number;
    v_count_rows_query2 number;
  begin
    execute immediate v_query1 into v_count_rows_query1;
    execute immediate v_query2 into v_count_rows_query2;
    
    if v_count_rows_query1 != v_count_rows_query2 then
      utt_logger.add(p_result => 'passed');
    else
      utt_logger.add('failed query 1 returns '||v_count_rows_query1||' rows and query2 returns '||v_count_rows_query2||' rows');
    end if;
  end;
  
  procedure assert_query_same_value(p_query1 in varchar2, p_query2 in varchar2) is
    v_value_query1 varchar2(4000);
    v_value_query2 varchar2(4000);
  begin
    if not validate_query(p_query1) or not validate_query(p_query2) then
      raise e_many_columns;
    end if;
    
    execute immediate p_query1 into v_value_query1;
    execute immediate p_query2 into v_value_query2;
    
    if v_value_query1 = v_value_query2 then
      utt_logger.add(p_result => 'passed');
    else
      utt_logger.add('failed query 1 returns '||v_value_query1||' and query2 returns '||v_value_query2);
    end if;
  exception
    when e_many_columns then
      utt_logger.add('more than one column on select clausule');
  end;
  
  procedure assert_query_diff_value(p_query1 in varchar2, p_query2 in varchar2) is
    v_value_query1 varchar2(4000);
    v_value_query2 varchar2(4000);
  begin
    if not validate_query(p_query1) or not validate_query(p_query2) then
      raise e_many_columns;
    end if;
  
    execute immediate p_query1 into v_value_query1;
    execute immediate p_query2 into v_value_query2;
    
    if v_value_query1 != v_value_query2 then
      utt_logger.add(p_result => 'passed');
    else
      utt_logger.add('failed query 1 returns '||v_value_query1||' and query2 returns '||v_value_query2);
    end if;
  exception
    when e_many_columns then
      utt_logger.add('more than one column on select clausule');
  end;
  
  procedure assert_dml_rowcount(p_expected in number) is
    v_rowcount number := sql%rowcount;
  begin
    if v_rowcount = p_expected then
      utt_logger.add(p_result => 'passed');
    else
      utt_logger.add('failed expected '||p_expected||' but inserted '||v_rowcount||' records');
    end if;
  end;
end utt;
/

alter package utt_logger compile;
/

alter package utt_logger compile body;
/

alter package utt compile;
/

alter package utt compile body;
/

show errors

grant execute on utt to public;
create public synonym utt for utt_user.utt;
create public synonym utt_logger for utt_user.utt_logger;

PROMPT
PROMPT Installation finished
PROMPT