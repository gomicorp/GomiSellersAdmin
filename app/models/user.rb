class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :omniauthable, omniauth_providers: [:facebook]

  # SNS 로그인 등 각종 로그인 정보
  has_many :authentications, dependent: :destroy

  # 역할과 관련된 스코프
  scope :admins, -> { where(is_admin: true) }
  scope :managers, -> { where(is_manager: true) }
  scope :sellers, -> { where(is_seller: true) }

  # 장바구니 또는 주문으로부터의 모델관계
  has_many :carts, -> { order(created_at: :desc) }
  has_many :order_infos, class_name: 'OrderInfo', through: :carts
  has_many :payments, class_name: 'Payment', through: :order_infos
  has_many :ship_infos, class_name: 'ShipInfo', through: :order_infos

  # 배송지에 대하여..
  has_many :user_shipping_address, dependent: :destroy
  has_many :shipping_addresses, through: :user_shipping_address
  belongs_to :default_address, class_name: 'ShippingAddress', optional: true

  # 수령인에 대하여..
  has_many :receivers, dependent: :destroy
  belongs_to :default_receiver, class_name: 'Receiver', optional: true

  def cart_attached?
    carts.active.any?
  end

  def current_cart
    carts.active.current
  end

  def current_receiver
    unless default_receiver
      update(default_receiver: receivers.first)
      reload
    end
    default_receiver
  end

  def current_address
    unless default_address
      update(default_address: shipping_addresses.first)
      reload
    end
    default_address
  end

  def self.find_for_oauth(auth, signed_in_resource = nil)
    user = signed_in_resource || Authentication.find_by(provider: auth.provider, uid: auth.uid)&.user

    # Directly return user if already exists or signed_in.
    return user if user

    # Make new user if user was not founded.

    # first, check any user has email what auth instance has.
    user = find_or_initialize_by(email: auth.info.email)

    unless user.persisted?
      # if nobody have this email, create new user.

      # Common Auth has.
      new_auth = Authentication.create provider: auth.provider, uid: auth.uid, user_id: user.id
      user.password = Devise.friendly_token[0, 20]

      # It's a little difference for each provider's auth hash.
      # Make sure which key and value of auth data is proper for users attributes.
      case auth.provider
      when 'facebook'
        user.email = auth.info.email || "#{auth.uid}@#{auth.provider}.gomicorp.com"
        user.name = auth.info.name
        user.profile_image = auth.info.image

      when 'kakao' # Note. Kakao doesn't support email field.
        user.profile_image = auth.info.image
      end

      new_auth.save!
      user.save!
    end

    user
  end

  # Enable to regist with doesn't have email field.
  def email_required?
    false
  end
end
