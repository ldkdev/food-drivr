class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :omniauthable, :omniauth_providers => [:twitter, :facebook]

  before_create :generate_authentication_token!
  after_initialize :set_defaults

  before_save :match_type_to_role

  validates :auth_token, uniqueness: true
  validates :role, presence: true

  has_one :organization
  has_one :setting, autosave: true, dependent: :destroy
  accepts_nested_attributes_for :setting
  accepts_nested_attributes_for :organization

  before_save { self.email = email.downcase }
  validates :name,  presence: true, length: { maximum: 50 }
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validates :email, presence: true, length: { maximum: 255 },
                    format: { with: VALID_EMAIL_REGEX },
                    uniqueness: { case_sensitive: false }
  validates :role, presence: true

  # User should have a role_id, although we may want to look into setting
  # Up separate classes.
  belongs_to :role

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.provider = auth.provider
      user.uid = auth.uid
      user.email = auth.info.email
      user.password = Devise.friendly_token[0,20]
    end
  end

  def generate_authentication_token!
    begin
      self.auth_token = Devise.friendly_token
    end while self.class.exists?(auth_token: auth_token)
  end

  def set_defaults
    match_type_to_role
    set_default_settings
  end

  def set_default_settings
    unless self.setting != nil
      if self.role_id == 0
        self.setting = Setting.create(active: true, notifications: false)
      else
        self.setting = Setting.create(active: false, notifications: false)
      end
    end
  end

  def settings
    self.setting
  end

  # Convenience method for updating settings for a user.
  def update_settings(settings = {})
    if self.setting
      self.setting.update(settings)
    else
      self.setting = Setting.create(settings)
    end
  end

  # Match the type of user to role and visa versa, providing backwords compatibility
  def match_type_to_role
    if self.role != nil || self.role_id != nil
      if !self.type || self.role.description.downcase != self.type.downcase
        @type = self.role.description.to_s.capitalize
        begin
          self.becomes!(Object.const_get(@type))
        rescue StandardError => error
          puts "Unable to convert type to: #{@type}"
        end
      end
    end
  end
end
