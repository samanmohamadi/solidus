require 'spec_helper'

module Spree
  module Stock
    describe Packer, type: :model do
      let!(:inventory_units) { 5.times.map { build(:inventory_unit) } }
      let(:stock_location) { create(:stock_location) }

      subject { Packer.new(stock_location, inventory_units) }

      context 'packages' do
        it 'builds an array of packages' do
          packages = subject.packages
          expect(packages.size).to eq 1
          expect(packages.first.contents.size).to eq 5
        end

        it 'allows users to set splitters to an empty array' do
          packages = Packer.new(stock_location, inventory_units, []).packages
          expect(packages.size).to eq 1
        end
      end

      context 'default_package' do
        it 'contains all the items' do
          package = subject.default_package
          expect(package.contents.size).to eq 5
        end

        it 'variants are added as backordered without enough on_hand' do
          inventory_units[0..2].each { |iu| stock_location.stock_item(iu.variant_id).set_count_on_hand(1) }
          inventory_units[3..4].each { |iu| stock_location.stock_item(iu.variant_id).set_count_on_hand(0) }

          package = subject.default_package
          expect(package.on_hand.size).to eq 3
          expect(package.backordered.size).to eq 2
        end

        context "location doesn't have order items in stock" do
          let(:stock_location) { create(:stock_location, propagate_all_variants: false) }
          let(:packer) { Packer.new(stock_location, inventory_units) }

          it "builds an empty package" do
            expect(packer.default_package).to be_empty
          end
        end

        context "none on hand and not backorderable" do
          let(:packer) { Packer.new(stock_location, inventory_units) }

          before do
            stock_location.stock_items.update_all(backorderable: false)
            stock_location.stock_items.each { |si| si.set_count_on_hand(0) }
          end

          it "builds an empty package" do
            expect(packer.default_package).to be_empty
          end
        end

        context "doesn't track inventory levels" do
          let(:variant) { build(:variant) }
          let(:order) { build(:order_with_line_items, line_items_count: 1) }
          let(:line_item) { order.line_items.first }
          let(:inventory_units) {
            30.times.map do
              build(
                :inventory_unit,
                order: order,
                line_item: line_item,
                variant: variant
              )
            end
          }

          before { Config.track_inventory_levels = false }

          it "doesn't bother stock items status in stock location" do
            expect(subject.stock_location).not_to receive(:fill_status)
            subject.default_package
          end

          it "still creates package with proper quantity" do
            expect(subject.default_package.quantity).to eql 30
          end
        end
      end
    end
  end
end
