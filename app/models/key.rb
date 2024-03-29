require 'digest/md5'

class Key < ActiveRecord::Base
  belongs_to :user
  belongs_to :project

  validates :title,
            :presence => true,
            :length   => { :within => 0..255 }

  validates :key,
            :presence => true,
            :length   => { :within => 0..5000 }

  before_save :set_identifier
  before_validation :strip_white_space
  delegate :name, :email, :to => :user, :prefix => true
  validate :unique_key

  def strip_white_space
    self.key = self.key.strip unless self.key.blank?
  end

  def unique_key
    query = Key.where(:key => key)
    query = query.where('(project_id IS NULL OR project_id = ?)', project_id) if project_id
    if (query.count > 0)
      errors.add :key, 'already exist.'
    end
  end

  def set_identifier
    if is_deploy_key
      self.identifier = "deploy_" + Digest::MD5.hexdigest(key)
    else
      self.identifier = "#{user.identifier}_#{Time.now.to_i}"
    end
  end

  def update_repository
    Gitlabhq::GitHost.system.new.configure do |c|
      c.update_keys(identifier, key)
      c.update_projects(projects)
    end
  end

  def repository_delete_key
    Gitlabhq::GitHost.system.new.configure do |c|
      #delete key file is there is no identically deploy keys
      if !is_deploy_key || Key.where(:identifier => identifier).count() == 0
        c.delete_key(identifier)
      end
      c.update_projects(projects)
    end
  end

  def is_deploy_key
    true if project_id
  end

   #projects that has this key
  def projects
    if is_deploy_key
      [project]
    else
      user.projects
    end
  end
end
# == Schema Information
#
# Table name: keys
#
#  id         :integer         not null, primary key
#  user_id    :integer
#  created_at :datetime
#  updated_at :datetime
#  key        :text
#  title      :string(255)
#  identifier :string(255)
#  project_id :integer
#

