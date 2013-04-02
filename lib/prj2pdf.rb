# /usr/bin/env ruby

require 'json'
require 'prawn'
require 'date'
require 'pp'

class PDFExporter
  def initialize(prj_json, out_path)
    raw_tasks = JSON.parse(prj_json)['tasks']
    tasks = raw_tasks.map{|m| Task.new m}
    Prawn::Document.generate(out_path, page_layout: :landscape) do |pdf|
      pdf.font_size 7

      drawer = TaskDrawer.new(pdf, tasks)
      drawer.draw
    end
  end

  class Task
    COLUMNS = %W(name start end assigs progress)
    attr_reader :name, :code, :level, :status,
    :assigs, :depends, :progress
    
    def initialize(task_hash)
      @name = task_hash['name']
      @code = task_hash['code']
      @level = task_hash['level']
      @status = task_hash['status']
      @start = Date.parse(Time.at(task_hash['start'] / 1000).to_s)
      @end =  Date.parse(Time.at(task_hash['end'] / 1000).to_s)
      @assigs = task_hash['assigs']
      @depends = task_hash['depends']
      @progress = task_hash['progress']
      @workload = task_hash['workload']
    end

    def to_table_array
      [@name, start_date, end_date, @assigs.to_s, abs_progress]
    end

    def duration
      (@end - @start).numerator + 1
    end

    DATE_FORAMT = '%Y-%m-%d'
    def start_date
      @start.strftime DATE_FORAMT
    end

    def end_date
      @end.strftime DATE_FORAMT
    end

    def assigs
      @assigs.join ','
    end

    def raw_start; @start end
    def raw_end;   @end   end

    def abs_progress
      "#{@progress}/#{@workload}"
    end

    def workload
      @workload || 100.0
    end
  end

  class TaskDrawer
    COL_INFO = [
                [60, :name],
                [60, :assigs],
                [40, :abs_progress],
                [40, :start_date],
                [40, :end_date],
               ]

    PADDING = 3

    def initialize(pdf, tasks)
      @pdf = pdf
      @tasks = tasks
      min_date = @tasks.map(&:raw_start).min
      max_date = @tasks.map(&:raw_end).max

      left = COL_INFO.map{|m| m[0]}.reduce(&:+)
      @calbb = {min: [left, 0], max:[720.0, 540]}

      @date_range = (min_date - 1)..(max_date + 1)
      @date_width = (@calbb[:max][0] - @calbb[:min][0]) / @date_range.count

      @task_prog_pos = {}
    end

    def date_to_x(date)
      @calbb[:min][0] + @date_width * (date - @date_range.first).numerator
    end

    def draw
      draw_calender
      draw_header
      draw_tasks
      draw_thunder
    end

    def draw_thunder
      @pdf.stroke{
        t = @tasks.first
        @pdf.move_to(@task_prog_pos[t]) if @task_prog_pos[t]

        @tasks.drop(1).each{|t|
          @pdf.line_to(@task_prog_pos[t]) if @task_prog_pos[t]
        }
      }
    end

    def draw_calender
      @pdf.stroke {
        @pdf.dash 1, space: 3
        @date_range.each_with_index{|d, i|
          day_x = @calbb[:min][0] + @date_width * i
          @pdf.line [day_x, 0], [day_x, @calbb[:max][1]]
        }
      }
      @pdf.undash

      @date_range.each_with_index{|d, i|
        day_x = @calbb[:min][0] + @date_width * i
        @pdf.text_box(d.day.to_s,
                      at: [day_x, @calbb[:max][1]])
        if d.day == 1 || i == 0
          @pdf.text_box("%d-%d"%[d.year, d.month],
                        at: [day_x, @calbb[:max][1] + 10])
        end
      }
    end

    def draw_columns(data, opts = {})
      x = 0
      y = @pdf.cursor
      bottom = y
      COL_INFO.zip(data).each do |_w, t|
        w = _w[0]
        @pdf.bounding_box([x, y],
                          width: w,
                          overflow: :shrink_to_fit,
                          min_font_size: nil) do
          @pdf.text t
          x += w
        end
        bottom = @pdf.cursor if  @pdf.cursor < bottom
      end
      yield(x, y) if block_given?

      @pdf.stroke{ @pdf.horizontal_rule} if opts[:underline]
      @pdf.move_cursor_to(bottom - PADDING)
    end

    TASKBAR_HEIGHT = 5

    def draw_tasks
      @tasks.each_with_index{|t, i|
        draw_columns(COL_INFO.map{|col|
                       message = col[1]
                       t.send message
                     }) do |x, y|
          @pdf.fill_color "000000"
          if i.odd?
            @pdf.transparent(0.15) {
              @pdf.fill{
                @pdf.rectangle [0,y + 2], @calbb[:max][0], 10
              }
            }
          end
          draw_taskbar t, x, y
        end

        if @pdf.cursor < 20
          @pdf.start_new_page
          draw_calender
          draw_header
        end
      }
    end

    def draw_taskbar(t, x, y)
      date_x = date_to_x t.raw_start
      bar_width = @date_width * t.duration
      progress = t.progress.to_f || 0.0
      workload = t.workload.to_f || 100.0
      progress_width = bar_width * progress / workload

      @pdf.fill_color "FFFFFF"
      @pdf.fill_rectangle([date_x, y], bar_width, TASKBAR_HEIGHT)

      @pdf.stroke_rectangle([date_x, y], bar_width, TASKBAR_HEIGHT)

      @pdf.fill_color "565656"
      @pdf.fill_rectangle([date_x, y], progress_width, TASKBAR_HEIGHT)
      
      @task_prog_pos[t] = [date_x + progress_width, y]
    end

    def draw_header
      draw_columns Task::COLUMNS, underline: true
    end
  end
end
