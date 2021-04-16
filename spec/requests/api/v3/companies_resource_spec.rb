#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2020 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
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

require 'spec_helper'
require 'rack/test'

describe 'API v3 companies resource', type: :request, content_type: :json do
  include Rack::Test::Methods
  include API::V3::Utilities::PathHelper

  let(:current_user) do
    FactoryBot.create(:user)
  end
  let(:admin) do
    FactoryBot.create(:admin)
  end
  let(:company) do
    FactoryBot.create(:company)
  end

  subject(:response) { last_response }

  describe 'GET /api/v3/companies/:id' do
    let(:path) { api_v3_paths.company(company.id) }

    before do
      login_as(current_user)

      get path
    end

    it 'returns 200 OK' do
      expect(subject.status)
        .to eql(200)
    end

    it 'returns the company' do
      expect(subject.body)
        .to be_json_eql('Company'.to_json)
        .at_path('_type')

      expect(subject.body)
        .to be_json_eql(company.id.to_json)
        .at_path('id')

      expect(subject.body)
        .to be_json_eql(company.name.to_json)
        .at_path('name')
    end

    context 'if querying a non existing company' do
      let(:path) { api_v3_paths.company(company.id + 1) }

      it_behaves_like 'not found'
    end

    context 'without begin logged in', with_settings: { login_required?: true } do
      let(:current_user) { nil }

      it_behaves_like 'unauthenticated access'
    end
  end

  describe 'PATCH /api/v3/companies/:id' do
    let(:current_user) { admin }
    let(:path) { api_v3_paths.company(company.id) }
    let(:new_name) { 'New name' }
    let(:body) do
      {
        name: new_name
      }.to_json
    end

    before do
      login_as(current_user)

      patch path, body
    end

    it 'returns 200 OK' do
      expect(subject.status)
        .to eql(200)
    end

    it 'returns the altered company' do
      expect(subject.body)
        .to be_json_eql('Company'.to_json)
        .at_path('_type')

      expect(subject.body)
        .to be_json_eql(company.id.to_json)
        .at_path('id')

      expect(subject.body)
        .to be_json_eql(new_name.to_json)
        .at_path('name')
    end

    context 'with a name not containing at least one alphabetical value' do
      let(:new_name) { '12345678' }

      # Ignoring the need for a more informative error message here.
      it_behaves_like 'error response',
                      422,
                      'PropertyConstraintViolation',
                      "Name #{I18n.t(:'activerecord.errors.messages.invalid')}"
    end

    context 'for a non admin' do
      let(:current_user) { FactoryBot.create(:user) }

      it_behaves_like 'unauthorized access'
    end

    context 'if querying a non existing company' do
      let(:path) { api_v3_paths.company(company.id + 1) }

      it_behaves_like 'not found'
    end

    context 'without being logged in', with_settings: { login_required?: true } do
      let(:current_user) { nil }

      it_behaves_like 'unauthenticated access'
    end
  end
end
