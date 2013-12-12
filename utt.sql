create or replace package utt is
--Author: Marcelo Cure
  e_many_columns exception;
  e_tests_failed exception;
  any_test_failed boolean := false;
  curr_procedure varchar2(32);
  curr_package varchar2(32);
  procedure run_all_tests(p_owner in varchar2 default user, p_package in varchar2);
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
  procedure assert_rownum_greater_than(p_table_name in varchar2, p_expected in number);
  procedure assert_rownum_lower_than(p_table_name in varchar2, p_expected in number);
  procedure assert_rownum_equals(p_table_name in varchar2, p_expected in number);
end utt;
/
create or replace package body utt is
  procedure execute_plsql(p_plsql in varchar2) is
  begin
    execute immediate p_plsql;
  end;

  procedure run_all_tests(p_owner in varchar2 default user , p_package in varchar2) is
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
      execute immediate replace(v_model,'<PROCEDURE>',curr_procedure);
    end loop;
    close c_tests;
    utt_logger.print_logger;
  exception
    when others then
      dbms_output.put_line(sqlerrm);
      dbms_output.put_line(dbms_utility.format_error_backtrace);
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
  
  procedure get_rownum(p_table_name in varchar2, p_object_exists out boolean, p_rowcount out number) is
    cursor c_rownum is
      select num_rows
      from all_tables
      where upper(table_name) = upper(p_table_name);
    v_rowcount number;
    v_object_exists boolean := true;
  begin
    open c_rownum;
    fetch c_rownum into v_rowcount;
    if c_rownum%notfound then
      v_object_exists := false;
      utt_logger.add(p_result => 'table or view doesn''t exist', p_procedure => curr_procedure);
    end if;
    close c_rownum;
    p_rowcount := v_rowcount;
    p_object_exists := v_object_exists;
  end;

  procedure assert_equals(p_expected in varchar2, p_actual in varchar2) is
  begin
    if p_expected = p_actual then
      utt_logger.add(p_result => 'passed',p_procedure => curr_procedure);
    else
      any_test_failed := true;
      utt_logger.add(p_result => build_failed_message(p_expected,p_actual), p_procedure => curr_procedure);
    end if;
  end;

  procedure assert_not_equals(p_expected in varchar2, p_actual in varchar2) is
  begin
    if p_expected != p_actual then
      utt_logger.add(p_result => 'passed', p_procedure => curr_procedure);
    else
      any_test_failed := true;
      utt_logger.add(build_failed_message(p_expected,p_actual), p_procedure => curr_procedure);
    end if;
  end;

  procedure assert_true(p_actual in boolean) is
  begin
    if p_actual then
      utt_logger.add(p_result => 'passed', p_procedure => curr_procedure);
    else
      any_test_failed := true;
      utt_logger.add(build_failed_message('true','false'), p_procedure => curr_procedure);
    end if;
  end;

  procedure assert_false(p_actual in boolean) is
  begin
    if not p_actual then
      utt_logger.add(p_result => 'passed', p_procedure => curr_procedure);
    else
      any_test_failed := true;
      utt_logger.add(build_failed_message('false','true'), p_procedure => curr_procedure);
    end if;
  end;

  procedure assert_null(p_actual in varchar2) is
  begin
    if p_actual is null then
      utt_logger.add(p_result => 'passed', p_procedure => curr_procedure);
    else
      any_test_failed := true;
      utt_logger.add(build_failed_message('not null',p_actual),p_procedure => curr_procedure);
    end if;
  end;

  procedure assert_not_null(p_actual in varchar2) is
  begin
    if p_actual is not null then
      utt_logger.add(p_result => 'passed', p_procedure => curr_procedure);
    else
      any_test_failed := true;
      utt_logger.add(build_failed_message('null',p_actual), p_procedure => curr_procedure);
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
      utt_logger.add(p_result => 'passed', p_procedure => curr_procedure);
    else
      any_test_failed := true;
      utt_logger.add(build_failed_message(upper(p_object_name),v_object_name), p_procedure => curr_procedure);
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
      utt_logger.add(p_result => 'passed', p_procedure => curr_procedure);
    else
      any_test_failed := true;
      utt_logger.add(build_failed_message('NONE',v_object_name), p_procedure => curr_procedure);
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
      utt_logger.add(p_result => 'passed', p_procedure => curr_procedure);
    else
      any_test_failed := true;
      utt_logger.add(p_result => 'failed query 1 returns '||v_count_rows_query1||' rows and query2 returns '||v_count_rows_query2||' rows', p_procedure => curr_procedure);
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
      utt_logger.add(p_result => 'passed', p_procedure => curr_procedure);
    else
      any_test_failed := true;
      utt_logger.add(p_result => 'failed query 1 returns '||v_count_rows_query1||' rows and query2 returns '||v_count_rows_query2||' rows', p_procedure => curr_procedure);
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
      utt_logger.add(p_result => 'passed', p_procedure => curr_procedure);
    else
      any_test_failed := true;
      utt_logger.add(p_result => 'failed query 1 returns '||v_value_query1||' and query2 returns '||v_value_query2, p_procedure => curr_procedure);
    end if;
  exception
    when e_many_columns then
      utt_logger.add(p_result => 'more than one column on select clausule', p_procedure => curr_procedure);
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
      utt_logger.add(p_result => 'passed', p_procedure => curr_procedure);
    else
      any_test_failed := true;
      utt_logger.add(p_result => 'failed query 1 returns '||v_value_query1||' and query2 returns '||v_value_query2, p_procedure => curr_procedure);
    end if;
  exception
    when e_many_columns then
      utt_logger.add(p_result => 'more than one column on select clausule',
                     p_procedure => curr_procedure);
  end;

  procedure assert_dml_rowcount(p_expected in number) is
    v_rowcount number := sql%rowcount;
  begin
    if v_rowcount = p_expected then
      utt_logger.add(p_result => 'passed', p_procedure => curr_procedure);
    else
      any_test_failed := true;
      utt_logger.add(p_result => 'failed expected '||p_expected||' but inserted '||v_rowcount||' records', p_procedure => curr_procedure);
    end if;
  end;
  
  procedure assert_rownum_greater_than(p_table_name in varchar2, p_expected in number) is
    v_rowcount number;
    v_object_exists boolean;
  begin
    get_rownum(p_table_name => p_table_name,
               p_object_exists => v_object_exists,
               p_rowcount => v_rowcount);
    if v_rowcount > p_expected then
      utt_logger.add(p_result => 'passed', p_procedure => curr_procedure);
    elsif v_object_exists then
      any_test_failed := true;
      utt_logger.add(p_result => 'failed expected more than'||p_expected||' but got '||v_rowcount, p_procedure => curr_procedure);
    end if;
  end;
  
  procedure assert_rownum_lower_than(p_table_name in varchar2, p_expected in number) is
    v_rowcount number;
    v_object_exists boolean;
  begin
    get_rownum(p_table_name => p_table_name,
               p_object_exists => v_object_exists,
               p_rowcount => v_rowcount);
    if v_rowcount < p_expected then
      utt_logger.add(p_result => 'passed', p_procedure => curr_procedure);
    elsif v_object_exists then
      any_test_failed := true;
      utt_logger.add(p_result => 'failed expected less than'||p_expected||' but got '||v_rowcount, p_procedure => curr_procedure);
    end if;
  end;
  
  procedure assert_rownum_equals(p_table_name in varchar2, p_expected in number) is
    v_rowcount number;
    v_object_exists boolean;
  begin
    get_rownum(p_table_name => p_table_name,
               p_object_exists => v_object_exists,
               p_rowcount => v_rowcount);
    if v_rowcount = p_expected then
      utt_logger.add(p_result => 'passed', p_procedure => curr_procedure);
    elsif v_object_exists then
      any_test_failed := true;
      utt_logger.add(p_result => 'failed expected '||p_expected||' but got '||v_rowcount, p_procedure => curr_procedure);
    end if;
  end;
end utt;
/
