class AddIndicesOnClassifications < ActiveRecord::Migration
  def self.up
    puts 'Unsure why but you need to run in script/console SubscriptionsUsers.connection.execute("update subscriptions_users set created_at = "2010-05-01 00:00:00" where created_at is null")'
    add_index :classifications, :user_id
    add_index :classifications, :entry_id
  end

  def self.down
    remove_index :classifications, :user_id
    remove_index :classifications, :entry_id
  end
end
