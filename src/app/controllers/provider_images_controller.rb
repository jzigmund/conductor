#
#   Copyright 2011 Red Hat, Inc.
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

class ProviderImagesController < ApplicationController
  before_filter :require_user

  def create
    image = Aeolus::Image::Warehouse::Image.find(params[:image_id])
    @environment = PoolFamily.where('name' => image.environment).first
    require_privilege(Privilege::USE, @environment)
    provider_account = ProviderAccount.find(params[:account_id])
    @provider_image = Aeolus::Image::Factory::ProviderImage.new(
      :provider => provider_account.provider.name,
      :credentials => provider_account.to_xml(:with_credentials => true),
      :image_id => params[:image_id],
      :build_id => params[:build_id],
      :target_image_id => params[:target_image_id]
    )
    begin
      if @provider_image.save
        flash[:notice] = _("Provider Image Upload Started")
        @push_started = true
      else
        flash[:warning] = _("Unable to Upload Provider Image")
      end
    rescue Exception => e
      logger.error "Caught exception importing image: #{e.message}"
      flash[:warning] = _("Unable to Upload Provider Image")
    end
    redirect_to image_path(params[:image_id], :build => params[:build_id], :push_started => @push_started,
                           :provider_account_id => @push_started ? provider_account.id : nil)
  end

  def destroy
    if image = Aeolus::Image::Warehouse::ProviderImage.find(params[:id])
      top_image = Aeolus::Image::Warehouse::Image.find(params[:image_id])
      @environment = PoolFamily.where('name' => top_image.environment).first
      require_privilege(Privilege::USE, @environment)
      target_id = image.target_identifier
      provider = image.provider
      i = image.target_image.build.image
      if i.imported?
        if i.delete!
          flash[:notice] = _("Image Deleted")
          redirect_to images_path
          return
        else
          flash[:warning] = _("Unable to Delete Image")
        end
      elsif image.delete!
        flash[:notice] = _("Provider Image Deleted. In order to remove the actual image stored by the Provider, visit the %s's management console and seek out the %s image.") % [target_id, provider]
      else
        flash[:warning] = _("Unable to Delete Provider Image")
      end
    else
      flash[:warning] = _("Provider Image not found")
    end
    build_id = image.build.id rescue nil
    redirect_to image_path(params[:image_id], :build => build_id)
  end
end
