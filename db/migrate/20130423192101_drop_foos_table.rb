class DropFoosTable < ActiveRecord::Migration
  def up
    # some old test table that managed to hang around
    drop_table :foos rescue nil
  end

  def down
  end
end
