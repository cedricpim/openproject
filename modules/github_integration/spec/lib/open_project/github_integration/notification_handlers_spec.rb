#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2021 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

require File.expand_path('../../../spec_helper', __dir__)

describe OpenProject::GithubIntegration::NotificationHandlers do
  before do
    allow(Setting).to receive(:host_name).and_return('example.net')
  end

  describe '.extract_work_package_ids' do
    it 'returns an empty array for an empty source' do
      result = described_class.send(
        :extract_work_package_ids, ''
      )
      expect(result).to eql([])
    end

    it 'finds a work package by code' do
      source = "Blabla\nOP#1234\n"
      result = described_class.send(
        :extract_work_package_ids, source
      )
      expect(result).to eql([1234])
    end

    it 'finds a plain work package url' do
      source = 'Blabla\nhttps://example.net/work_packages/234\n'
      result = described_class.send(
        :extract_work_package_ids, source
      )
      expect(result).to eql([234])
    end

    it 'finds a work package url in markdown link syntax' do
      source = 'Blabla\n[WP 234](https://example.net/work_packages/234)\n'
      result = described_class.send(
        :extract_work_package_ids, source
      )
      expect(result).to eql([234])
    end

    it 'finds multiple work package urls' do
      source = "I reference https://example.net/work_packages/434\n and Blabla\n[WP 234](https://example.net/wp/234)\n"
      result = described_class.send(
        :extract_work_package_ids, source
      )
      expect(result).to eql([434, 234])
    end

    it 'finds multiple occurences of a work package only once' do
      source = "I reference https://example.net/work_packages/434\n and Blabla\n[WP 234](https://example.net/work_packages/434)\n"
      result = described_class.send(
        :extract_work_package_ids, source
      )
      expect(result).to eql([434])
    end
  end

  describe '.find_visible_work_packages' do
    let(:user) { instance_double(User) }
    let(:visible_wp) { instance_double(WorkPackage, project: :project_with_permissions) }
    let(:invisible_wp) { instance_double(WorkPackage, project: :project_without_permissions) }

    shared_examples_for 'GithubIntegration.find_visible_work_packages' do
      subject(:find_visible_work_packages) do
        described_class.send(
          :find_visible_work_packages, ids, user
        )
      end

      before do
        allow(WorkPackage).to receive(:includes).and_return(WorkPackage)
        allow(WorkPackage).to receive(:where).with(id: ids).and_return(work_packages)
        allow(user).to receive(:allowed_to?) { |permission, project|
          (permission == :add_work_package_notes) && (project == :project_with_permissions)
        }
      end

      it 'processes the notification' do
        expect(find_visible_work_packages).to eql(expected)
        expect(user).to have_received(:allowed_to?).exactly(ids.length).times
      end
    end

    describe 'should find an existing work package' do
      let(:work_packages) { [visible_wp] }
      let(:ids) { [0] }
      let(:expected) { work_packages }

      it_behaves_like 'GithubIntegration.find_visible_work_packages'
    end

    describe 'should not find a non-existing work package' do
      let(:work_packages) { [invisible_wp] }
      let(:ids) { [0] }
      let(:expected) { [] }

      it_behaves_like 'GithubIntegration.find_visible_work_packages'
    end

    describe 'should find multiple existing work packages' do
      let(:work_packages) { [visible_wp, visible_wp] }
      let(:ids) { [0, 1] }
      let(:expected) { work_packages }

      it_behaves_like 'GithubIntegration.find_visible_work_packages'
    end

    describe 'should not find work package which the user shall not see' do
      let(:work_packages) { [visible_wp, invisible_wp, visible_wp, invisible_wp] }
      let(:ids) { [0, 1, 2, 3] }
      let(:expected) { [visible_wp, visible_wp] }

      it_behaves_like 'GithubIntegration.find_visible_work_packages'
    end
  end

  describe '.issue_comment' do
    context 'when an issue request is not a pull request' do
      let(:payload) do
        { 'action' => 'created',
          'issue' => { 'pull_request' => { 'html_url' => nil } } }
      end

      before do
        allow(WorkPackages::UpdateService).to receive(:new)
      end

      it 'does not add comments to work packages' do
        described_class.issue_comment(payload)
        expect(WorkPackages::UpdateService).not_to have_received(:new)
      end
    end
  end

  describe '.pull_request' do
    context 'with a synchronize action' do
      let(:payload) { { 'action' => 'synchronize' } }

      before do
        allow(WorkPackages::UpdateService).to receive(:new)
      end

      it 'does not add comments to work packages' do
        described_class.pull_request(payload)
        expect(WorkPackages::UpdateService).not_to have_received(:new)
      end
    end
  end
end
