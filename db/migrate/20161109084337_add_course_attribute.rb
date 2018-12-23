class AddCourseAttribute < ActiveRecord::Migration
  def change
    add_column :courses, :open, :boolean, default: true
    execute <<-SQL
        create or replace function increment_student_num()
          returns trigger as $increment_student_num$
        begin
          update courses set student_num = student_num + 1 where courses.id = new.course_id;
          return new;
        end;
        $increment_student_num$ LANGUAGE plpgsql;
        
        create trigger "increment_student_num"
          after insert
          on grades
          for each row execute procedure increment_student_num();
        
        create or replace function minus_student_num()
          returns trigger as $minus_student_num$
        begin
          update courses set student_num = student_num - 1 where courses.id = old.course_id;
          return new;
        end;
        $minus_student_num$ LANGUAGE plpgsql;
        create trigger "minus_student_num"
          after delete
          on grades
          for each row execute procedure minus_student_num();
    SQL
  end
end
