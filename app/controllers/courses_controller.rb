require 'will_paginate/array'
class CoursesController < ApplicationController

  before_action :student_logged_in, only: [:select, :quit, :list, :guide]
  before_action :teacher_logged_in, only: [:new, :create, :edit, :destroy, :update, :open, :close]#add open by qiao
  before_action :logged_in, only: :index

  #-------------------------for teachers----------------------

  def new
    @course=Course.new
  end

  def create
    @course = Course.new(course_params)
    if @course.save
      current_user.teaching_courses<<@course
      redirect_to courses_path, flash: {success: "新课程申请成功"}
    else
      flash[:warning] = "信息填写有误,请重试"
      render 'new'
    end
  end

  def edit
    @course=Course.find_by_id(params[:id])
  end

  def update
    @course = Course.find_by_id(params[:id])
    if @course.update_attributes(course_params)
      flash={:info => "更新成功"}
    else
      flash={:warning => "更新失败"}
    end
    redirect_to courses_path, flash: flash
  end

  def open
    @course=Course.find_by_id(params[:id])
    @course.update_attributes(open: true)
    redirect_to courses_path, flash: {:success => "已经成功开启该课程:#{ @course.name}"}
  end

  def close
    @course=Course.find_by_id(params[:id])
    @course.update_attributes(open: false)
    redirect_to courses_path, flash: {:success => "已经成功关闭该课程:#{ @course.name}"}
  end

  def destroy
    @course=Course.find_by_id(params[:id])
    current_user.teaching_courses.delete(@course)
    @course.destroy
    flash={:success => "成功删除课程: #{@course.name}"}
    redirect_to courses_path, flash: flash
  end

  #-------------------------for students----------------------
  def table
    @table_course = {}
    @weekday_list = %i[周一 周二 周三 周四 周五 周六 周日]
    @course_time_list = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    @weekday_list.each do |day|
      @table_course[day] = {}
    end
    current_user.courses.each do |course|
      week_key = course.course_time[0, 2].to_sym
      course_order_start = course.course_time[/.*\(([\d]*)-([\d]*)\)/, 1].to_i
      course_order_end = course.course_time[/.*\(([\d]*)-([\d]*)\)/, 2].to_i
      span = course_order_end - course_order_start + 1
      @table_course[week_key][course_order_start] = {
          start: course_order_start, span: span, name: course.name, course_time: course.course_time,
          course_week: course.course_week, class_room: course.class_room
      }
      (course_order_start + 1..course_order_end).each do |iter|
        @table_course[week_key][iter] = {start: course_order_start}
      end
    end
  end

  def guide
    credits = Course.joins('JOIN grades ON courses.id = grades.course_id')
                   .select('course_type as type, sum(cast((substr(credit, 4, 5)) as float)) as get')
                   .where('user_id = ?', session[:user_id]).group('course_type')
    course_type_list = [['专业研讨课', 20], ['专业核心课', 60],
                        ['专业普及课', 46], ['一级学科普及课', 40],
                        ['一级学科核心课', 60], ['公共选修课', 40]]
    @credits = []
    course_type_list.each do |course_type|
      get = 0
      credits.each do |credit|
        get = credit.get if credit.type == course_type[0]
      end
      @credits.append({:type=>course_type[0], :get=>get, :require=>course_type[1]})
    end
  end

  def search
    @courses = Course.where('course_time like ? and course_type like ? and name like ? and open = ?',
                            params[:course_time] + '%', params[:course_type] + '%', '%' + params[:name] + '%', true).order(:id)
    @courses = @courses.paginate(page: params[:page], per_page: 8)
    render 'list'
  end

  def list
    #-------QiaoCode--------
    @courses = Course.where(:open=>true).order(:id)
    @courses = @courses.paginate(page: params[:page], per_page: 8
    )
  end

  def select
    @course=Course.find_by_id(params[:id])
    flash = {}
    if !@course.limit_num.nil? and @course.student_num == @course.limit_num
      flash[:danger] = '该课程已到限选人数'
    else # rule check for duplicate and time conflict
      week_key = @course.course_time[0, 2]
      course_order_start = @course.course_time[/.*\(([\d]*)-([\d]*)\)/, 1].to_i
      course_order_end = @course.course_time[/.*\(([\d]*)-([\d]*)\)/, 2].to_i
      course_order_range = course_order_start..course_order_end
      # loop in courses to check rule
      current_user.courses.each do |course|
        if course.id == @course.id
          flash[:danger] = "你过去已经选择了课程：#{course.name}"
          break
        end
        week_key_iter = course.course_time[0, 2]
        course_order_start_iter = course.course_time[/.*\(([\d]*)-([\d]*)\)/, 1].to_i
        course_order_end_iter = course.course_time[/.*\(([\d]*)-([\d]*)\)/, 2].to_i
        if week_key == week_key_iter && (course_order_range.include?(course_order_start_iter) || course_order_range.include?(course_order_end_iter))
          flash[:danger] = "#{@course.name}和#{course.name}在时间上存在冲突"
          break
        end
      end
    end
    # rule check end
    if flash.empty?
      current_user.courses << @course
      @course.student_num = @course.student_num + 1
      @course.save
      flash = {success: "成功选择课程: #{@course.name}"}
    end
    redirect_to courses_path, flash: flash
  end

  def quit
    @course=Course.find_by_id(params[:id])
    current_user.courses.delete(@course)
    @course.student_num = @course.student_num - 1
    @course.save
    flash={success: "成功退选课程: #{@course.name}"}
    redirect_to courses_path, flash: flash
  end


  #-------------------------for both teachers and students----------------------

  def index
    @course=current_user.teaching_courses.paginate(page: params[:page], per_page: 4) if teacher_logged_in?
    @course=current_user.courses.paginate(page: params[:page], per_page: 10) if student_logged_in?
  end


  private

  # Confirms a student logged-in user.
  def student_logged_in
    unless student_logged_in?
      redirect_to root_url, flash: {danger: '请登陆'}
    end
  end

  # Confirms a teacher logged-in user.
  def teacher_logged_in
    unless teacher_logged_in?
      redirect_to root_url, flash: {danger: '请登陆'}
    end
  end

  # Confirms a  logged-in user.
  def logged_in
    unless logged_in?
      redirect_to root_url, flash: {danger: '请登陆'}
    end
  end

  def course_params
    params.require(:course).permit(:course_code, :name, :course_type, :teaching_type, :exam_type,
                                   :credit, :limit_num, :class_room, :course_time, :course_week)
  end


end
