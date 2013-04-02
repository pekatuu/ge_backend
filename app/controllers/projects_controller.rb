require 'json'
require 'prj2pdf'

class ProjectsController < ApplicationController
  before_filter :authenticate_user!
  
  def export
    @project = Project.find(params[:project_id])
    export_path = "%s-%d.pdf"%[@project.name, @project.lock_version]
    PDFExporter.new(@project.data, export_path)
    send_file export_path
  end    

  # GET /projects
  # GET /projects.json
  def index
    @projects = Project.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @projects }
    end
  end

  # GET /projects/1
  # GET /projects/1.json
  def show
    @project = Project.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { 
        render json: successful_response(@project)
      }
    end
  end

  # GET /projects/new
  # GET /projects/new.json
  def new
    @project = Project.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @project }
    end
  end

  # GET /projects/1/edit
  def edit
    @project = Project.find(params[:id])
  end

  # POST /projects
  # POST /projects.json
  def create
    @project = Project.new(params[:project])

    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: 'Project was successfully created.' }
        format.json { render json: @project, status: :created, location: @project }
      else
        format.html { render action: "new" }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /projects/1
  # PUT /projects/1.json
  def update
    @project = Project.find(params[:id])
    @project.data = params[:prj]
    @project.lock_version = params[:lock_version]
    last_edit_user = @project.last_edit_user
    @project.last_edit_user = current_user.email

    respond_to do |format|
      if @project.update_attributes(params[:project])
        format.html { redirect_to @project, notice: 'Project was successfully updated.' }
        format.json { render json: successful_response(@project) }
      else
        format.html { render action: "edit" }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  rescue ActiveRecord::StaleObjectError
    render json: {
      message: 'update conflict. please reload and save again',
      errorMessages: [
                      "",
                      "	last update at: #{@project.updated_at}",
                      "	by user: #{last_edit_user}"
                     ]
    }
  end

  # DELETE /projects/1
  # DELETE /projects/1.json
  def destroy
    @project = Project.find(params[:id])
    @project.destroy

    respond_to do |format|
      format.html { redirect_to projects_url }
      format.json { head :no_content }
    end
  end

  def successful_response(prj)
    {
      ok: :ok,
      project: JSON.parse(prj.data).merge(resources: User.to_resoruces)
    }
  end
end
