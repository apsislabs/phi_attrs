# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'extend_phi_access' do
  before(:all) do
    ActiveRecord::Schema.define do
      create_table :extend_access_children, force: true do |t|
        t.string :first_name
        t.timestamps
      end

      create_table :extend_access_parents, force: true do |t|
        t.references :extend_access_child
        t.string :name
        t.timestamps
      end
    end

    class ExtendAccessChild < ApplicationRecord
      self.table_name = 'extend_access_children'

      phi_model
      exclude_from_phi :id, :created_at, :updated_at

      def serializable_hash(options = nil)
        super.tap do |hash|
          hash['echo_first_name'] = first_name
        end
      end
    end

    class ExtendAccessParent < ApplicationRecord
      self.table_name = 'extend_access_parents'
      belongs_to :extend_access_child

      phi_model
      exclude_from_phi :id, :extend_access_child_id, :created_at, :updated_at
      extend_phi_access :extend_access_child

      def child_hash
        extend_access_child.serializable_hash
      end
    end
  end

  it 'does not make implicit new-record access a durable extension' do
    child = ExtendAccessChild.create!(first_name: 'Jane')
    parent = ExtendAccessParent.new(name: 'parent', extend_access_child: child)

    # New records have implicit PHI access. Touching the relation before the
    # parent is saved should not grant or track access on the persisted child.
    parent.extend_access_child
    expect(child.phi_allowed?).to be(false)
    expect(parent.instance_variable_get(:@__phi_relations_extended)).not_to include(child)

    parent.save!

    expect do
      parent.get_phi('user@example.com', 'serialize child') { parent.child_hash }
    end.not_to raise_error
  end

  it 're-grants an extended relation when the tracked relation is stale' do
    child = ExtendAccessChild.create!(first_name: 'Jane')
    parent = ExtendAccessParent.create!(name: 'parent', extend_access_child: child)

    parent.instance_variable_get(:@__phi_relations_extended).add(child)
    expect(child.phi_allowed?).to be(false)

    expect do
      parent.get_phi('user@example.com', 'serialize child') { parent.child_hash }
    end.not_to raise_error
  end
end
