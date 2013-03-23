class AddLockingToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :lock_version, :integer, default: 0
    add_column :projects, :last_edit_user, :string
  end
end
