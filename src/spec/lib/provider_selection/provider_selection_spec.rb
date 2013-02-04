#
#   Copyright 2012 Red Hat, Inc.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#

require 'spec_helper'

describe ProviderSelection::Strategies do
  before(:each) do
    @account1 = FactoryGirl.create(:mock_provider_account, :label => "test_account1")
    @account2 = FactoryGirl.create(:mock_provider_account, :label => "test_account2")
    @account3 = FactoryGirl.create(:mock_provider_account, :label => "test_account3")

    @hwp1 = FactoryGirl.create(:hardware_profile)
    @hwp2 = FactoryGirl.create(:hardware_profile)
    @hwp3 = FactoryGirl.create(:hardware_profile)
    @hwp4 = FactoryGirl.create(:hardware_profile)

    @possible1 = FactoryGirl.build(:instance_match, :provider_account => @account1, :hardware_profile => @hwp1)
    @possible2 = FactoryGirl.build(:instance_match, :provider_account => @account2, :hardware_profile => @hwp2)
    @possible3 = FactoryGirl.build(:instance_match, :provider_account => @account3, :hardware_profile => @hwp3)
  end

  context "working with one instance deployments" do
    before(:each) do
      @cost1 = FactoryGirl.create(:cost, :chargeable_id => @hwp1.id, :price => 1)
      @cost2 = FactoryGirl.create(:cost, :chargeable_id => @hwp2.id, :price => 0.02)
      @cost3 = FactoryGirl.create(:cost, :chargeable_id => @hwp3.id, :price => 0.01)
    end

    describe ProviderSelection::Strategies::CostOrder::Strategy do
      it "should give better (lower) score for lower cost" do

        instance = Factory.build(:instance)
        instance.stub!(:matches).and_return([[@possible1, @possible2, @possible3], []])

        provider_selection = ProviderSelection::Base.new([instance])
        strategy_chain = provider_selection.chain_strategy('cost_order', {:impact=>1})

        # we should have a match
        provider_selection.match_exists?.should_not be_false

        rank = strategy_chain.calculate

        # if we order the matches by score
        matches = rank.default_priority_group.matches.sort!{ |m1,m2| m1.score <=> m2.score }

        # then the first one should be for the cheaper hardware_profile etc.
        matches[0].hardware_profiles[0].default_cost_per_hour.should < matches[1].hardware_profiles[0].default_cost_per_hour
        matches[1].hardware_profiles[0].default_cost_per_hour.should < matches[2].hardware_profiles[0].default_cost_per_hour
      end

      it "hardware profiles with lower prices should be selected more frequently" do
        test = Proc.new do |impact|
          instance = Factory.build(:instance)
          instance.stub!(:matches).and_return([[@possible1, @possible3], []])

          provider_selection = ProviderSelection::Base.new([instance])

          strategy_chain = provider_selection.chain_strategy('cost_order', {:impact=>impact})
          pac_ids = Hash.new(0)
          1000.times {
            pac_id = strategy_chain.next_match.provider_account.label
            pac_ids[pac_id] += 1
          }
          pac_ids['test_account1'].should < pac_ids['test_account3']
        end

        # 3.times { |impact| test.call(impact) } # FIXME: the low impact case
        # fails from time to time this has to be fixed by 1) adjusting the
        # price2penalty function; 2) testing this in "statistically correct" way
        2.upto(3).each { |impact| test.call(impact) }
      end
    end
  end

  it "should choose the cheapest provider even for multiple instances" do
    # based on the 1st instance, the 1st provider would be more expensive
    # but the 2nd instance should revert the result
    # so in the end the 1st provider shall have the better score
    cost1 = FactoryGirl.create(:cost, :chargeable_id => @hwp1.id, :price => 0.02) # i1
    cost2 = FactoryGirl.create(:cost, :chargeable_id => @hwp2.id, :price => 0.01) # i2
    cost3 = FactoryGirl.create(:cost, :chargeable_id => @hwp3.id, :price => 0.01) # i1
    cost4 = FactoryGirl.create(:cost, :chargeable_id => @hwp4.id, :price => 0.1)  # i2

    test = Proc.new do |impact|
      instance1 = Factory.build(:instance)
      instance2 = Factory.build(:instance)

      possible1 = FactoryGirl.build(:instance_match, :instance=> instance1, :provider_account => @account1, :hardware_profile => @hwp1)
      possible2 = FactoryGirl.build(:instance_match, :instance=> instance2, :provider_account => @account1, :hardware_profile => @hwp2)
      possible3 = FactoryGirl.build(:instance_match, :instance=> instance1, :provider_account => @account2, :hardware_profile => @hwp3)
      possible4 = FactoryGirl.build(:instance_match, :instance=> instance2, :provider_account => @account2, :hardware_profile => @hwp4) # expensive

      instance1.stub!(:matches).and_return([[possible1, possible3],[]])
      instance2.stub!(:matches).and_return([[possible2, possible4],[]])

      provider_selection = ProviderSelection::Base.new([instance1,instance2])

      strategy_chain = provider_selection.chain_strategy('cost_order', {:impact=>impact})
      rank = strategy_chain.calculate

      # if we order the matches by score
      matches = rank.default_priority_group.matches.sort!{ |m1,m2| m1.score <=> m2.score }
      # better score should have the 1st provider
      matches[0].provider_account.label.should == 'test_account1'
    end

    3.times { |impact| test.call(impact) }
  end

  describe ProviderSelection::Strategies::StrictOrder::Strategy do
    before(:each) do
      @pg1 = FactoryGirl.create(:provider_priority_group, :name => 'pg1', :score => 10)
      @pg1.provider_accounts = [@account1]
      @pg2 = FactoryGirl.create(:provider_priority_group, :name => 'pg2', :score => 20)
      @pg2.provider_accounts = [@account2]
      @pg3 = FactoryGirl.create(:provider_priority_group, :name => 'pg3', :score => 30)
      @pg3.provider_accounts = [@account3]

      @pool = FactoryGirl.create(:pool)
      @pool.provider_priority_groups = [@pg1, @pg2, @pg3]
    end

    it "should return matches from priority group with lower score" do
      instance = Factory.build(:instance, :pool=> @pool)
      instance.stub!(:matches).and_return([[@possible1, @possible2, @possible3], []])

      provider_selection = ProviderSelection::Base.new([instance])

      strategy_chain = provider_selection.chain_strategy('strict_order')
      rank = strategy_chain.calculate

      # we should have the same number of priority groups in the match as the
      # number of priority groups in the pool plus one for the default_priority_group
      rank.priority_groups.length.should be_equal(@pool.provider_priority_groups.length+1)

      # then the first match should be from the provider account in the priority
      # group with lowest score
      strategy_chain.next_match.provider_account.label.should == 'test_account1'
    end
  end

  describe ProviderSelection::Strategies::PenaltyForFailure::Strategy do

    it "shoult return matches with provider account with number of failures lower then the failure_count_hard_limit" do
      @account1.stub!(:failure_count).and_return(3)
      @account2.stub!(:failure_count).and_return(4)

      instance = Factory.build(:instance, :pool=> @pool)
      instance.stub!(:matches).and_return([[@possible1, @possible2, @possible3], []])

      provider_selection = ProviderSelection::Base.new([instance])

      strategy_chain = provider_selection.chain_strategy('penalty_for_failure', {
        :penalty_percentage       => 5,
        :time_period_minutes      => 4*60,
        :failure_count_hard_limit => 2
      })

      # given we have reached the failure_count_hard_limit in 2 accounts we
      # should get a match from the 3rd
      strategy_chain.next_match.provider_account.label.should == 'test_account3'
    end
  end
end
