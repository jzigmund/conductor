class Admin::ProvidersController < ApplicationController
  before_filter :require_user
  before_filter :set_view_envs, :only => [:show, :index]

  def index
    @params = params
    @search_term = params[:q]
    if @search_term.blank?
      load_providers
      return
    end

    search = Provider.search do
      keywords(params[:q])
    end
    @providers = search.results
  end

  def new
    require_privilege(Privilege::CREATE, Provider)
    @provider = Provider.new
    kick_condor
  end

  def edit
    @provider = Provider.find_by_id(params[:id])
    require_privilege(Privilege::MODIFY, @provider)
  end

  def show
    load_providers
    @provider = Provider.find(params[:id])
    @hardware_profiles = @provider.hardware_profiles
    @realm_names = @provider.realms.collect { |r| r.name }

    @url_params = params.clone
    require_privilege(Privilege::VIEW, @provider)
    @tab_captions = ['Properties', 'HW Profiles', 'Realms', 'Provider Accounts', 'Services','History','Permissions']
    @details_tab = params[:details_tab].blank? ? 'properties' : params[:details_tab]

    if params.delete :test_provider
      test_connection(@provider)
    end

    respond_to do |format|
      format.js do
        if @url_params.delete :details_pane
          render :partial => 'layouts/details_pane' and return
        end
        render :partial => @details_tab and return
      end
      format.html { render :action => 'show' }
    end
  end

  def create
    require_privilege(Privilege::CREATE, Provider)
    if params[:provider].has_key?(:provider_type_codename)
      provider_type = params[:provider].delete(:provider_type_codename)
      provider_type = ProviderType.find_by_codename(provider_type)
      params[:provider][:provider_type_id] = provider_type.id
    end
    @provider = Provider.new(params[:provider])
    if !@provider.connect
      flash[:notice] = "Failed to connect to Provider"
      render :action => "new"
    else
      if @provider.save && @provider.populate_hardware_profiles
        @provider.assign_owner_roles(current_user)
        flash[:notice] = "Provider added."
        redirect_to admin_providers_path
      else
        flash[:notice] = "Cannot add the provider."
        render :action => "new"
      end
      kick_condor
    end
  end

  def update
    @provider = Provider.find_by_id(params[:id])
    require_privilege(Privilege::MODIFY, @provider)
    @provider.update_attributes(params[:provider])
    if !@provider.connect
      flash[:notice] = "Failed to connect to Provider"
      render :action => "edit"
    else
      if @provider.errors.empty? and @provider.save
        flash[:notice] = "Provider updated."
        redirect_to admin_providers_path
      else
        flash[:notice] = "Cannot update the provider."
        render :action => 'edit'
      end
    end
    kick_condor
  end

  def multi_destroy
    Provider.find(params[:provider_selected]).each do |provider|
      provider.destroy if check_privilege(Privilege::MODIFY, provider)
    end
    redirect_to admin_providers_url
  end

  def test_connection(provider)
    @provider.errors.clear
    if @provider.connect
      flash[:notice] = "Successfuly Connected to Provider"
    else
      flash[:notice] = "Failed to Connect to Provider"
      @provider.errors.add :url
    end
  end

  protected
  def set_view_envs
    @header = [{ :name => "Provider name", :sort_attr => :name },
               { :name => "Provider URL", :sort_attr => :name }
    ]
    @url_params = params.clone
  end

    def load_providers
      @header = [{ :name => "Provider name", :sort_attr => :name },
                 { :name => "Provider URL", :sort_attr => :name },
                 { :name => "Provider Type", :sort_attr => :name }
      ]
      @providers = Provider.list_for_user(@current_user, Privilege::VIEW)
      @url_params = params.clone
    end
end
