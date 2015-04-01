class AddUniqueIdToDelayedJobs < ActiveRecord::Migration
  def self.up
    add_column :delayed_jobs, :unique_id, :string
    add_index :delayed_jobs, [:priority, :run_at, :unique_id], name: "delayed_jobs_priority_unique_id"
  end

  def self.down
    remove_index :delayed_jobs, name: "delayed_jobs_priority_unique_id"
    remove_column :delayed_jobs, :unique_id
  end
end
