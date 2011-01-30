class AddNamesToClassifications < ActiveRecord::Migration
  def self.up
    add_column :classifications, :name, :string, :default=>nil
  end

  def self.down
    remove_column :classifications, :name
  end
end
