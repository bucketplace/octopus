require 'spec_helper'

describe 'when the database is replicated and has slave groups and has a default slave group' do

    it 'should pick the slave group based on current_slave_grup when you have a replicated model' do

        OctopusHelper.using_environment :replicated_slave_grouped_with_default do
            # The following two calls of `create!` both creates cats in :master(The database `octopus_shard_1`)
            # which is configured through RAILS_ENV and database.yml
            Cat.create!(:name => 'Thiago1')
            Cat.create!(:name => 'Thiago2')

            # See "replicated_slave_grouped" defined in shards.yml
            # We have:
            #   The database `octopus_shard_1` as :slave21 which is a member of the slave group :slaves2, and as :master
            #   The databse `octopus_shard_2` as :slave11 which is a member of the slave group :slaves1
            # When a select-count query is sent to `octopus_shard_1`, it should return 2 because we have create two cats in :master .
            # When a select-count query is sent to `octopus_shard_2`, it should return 0.

            # The query goes to `octopus_shard_1`
            expect(Cat.using(:master).count).to eq(2)
            # The query goes to `octopus_shard_2`
            expect(Cat.count).to eq(0)
            # The query goes to `octopus_shard_2`
            expect(Cat.using(:slave_group => :slaves1).count).to eq(0)
            # The query goes to `octopus_shard_1`
            expect(Cat.using(:slave_group => :slaves2).count).to eq(2)
        end
    end

    it 'should make queries to default slave group when slave groups are configured but not selected' do
        OctopusHelper.using_environment :replicated_slave_grouped_with_default do
            # `create!` queries go to :master(`octopus_shard_1`), `.count` queries go to :slaves1(`octopus_shard_2`)

            Cat.create!(:name => 'Thiago1')
            Cat.create!(:name => 'Thiago2')

            # In `database.yml` and `shards.yml`, we have configured 1 master and 4 slaves.
            # So we can ensure Octopus is not distributing queries between them
            # by asserting 1 + 4 = 5 queries go to :slaves1(`octopus_shard_2`)
            expect(Cat.count).to eq(0)
            expect(Cat.count).to eq(0)
            expect(Cat.count).to eq(0)
            expect(Cat.count).to eq(0)
            expect(Cat.count).to eq(0)
        end
    end

    it 'should keep sending to slaves in a using block which specifies a slave group' do
        OctopusHelper.using_environment :replicated_slave_grouped_with_default do
            Cat.create!(:name => 'Thiago1')
            Cat.create!(:name => 'Thiago2')

            expect(Cat.count).to eq(0)
            Octopus.using(:slave_group => :slaves2) do
                expect(Cat.count).to eq(2)
                expect(Cat.count).to eq(2)
            end
        end
    end

    it 'should keep sending to slaves in a using block which specifies a slave' do
        OctopusHelper.using_environment :replicated_slave_grouped_with_default do
            Cat.create!(:name => 'Thiago1')
            Cat.create!(:name => 'Thiago2')

            expect(Cat.count).to eq(0)
            Octopus.using(:slave21) do
                expect(Cat.count).to eq(2)
                expect(Cat.count).to eq(2)
            end

            Octopus.using(:slave31) do
                expect(Cat.count).to eq(2)
                expect(Cat.count).to eq(2)
            end

            Octopus.using(:slave32) do
                expect(Cat.count).to eq(0)
                expect(Cat.count).to eq(0)
            end
        end
    end

    it 'should send to master in a using block which specifies master' do
        OctopusHelper.using_environment :replicated_slave_grouped_with_default do
            Cat.create!(:name => 'Thiago1')
            Cat.create!(:name => 'Thiago2')

            expect(Cat.count).to eq(0)
            Octopus.using(:master) do
                expect(Cat.count).to eq(2)
                expect(Cat.count).to eq(2)
            end
        end
    end

    it 'should restore previous slave group after a using block which specifies a slave group' do
        OctopusHelper.using_environment :replicated_slave_grouped_with_default do
            Cat.create!(:name => 'Thiago1')
            Cat.create!(:name => 'Thiago2')

            Octopus.using(:slave_group => :slaves2) do
                Octopus.using(:slave_group => :slaves1) do
                    expect(Cat.count).to eq(0)
                end
                expect(Cat.count).to eq(2)
            end
        end
    end

    it 'should restore previous slave after a using block which specifies a slave' do
        OctopusHelper.using_environment :replicated_slave_grouped_with_default do
            Cat.create!(:name => 'Thiago1')
            Cat.create!(:name => 'Thiago2')

            expect(Cat.count).to eq(0)
            Octopus.using(:slave21) do
                Octopus.using(:slave11) do
                    expect(Cat.count).to eq(0)
                end
                expect(Cat.count).to eq(2)
            end
            expect(Cat.count).to eq(0)
        end
    end
end

