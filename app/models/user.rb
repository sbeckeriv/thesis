class User < ActiveRecord::Base
  has_many :metadata, :class_name => "Metadata"
  has_many :classifications
  has_and_belongs_to_many :subscriptions

  before_create :set_modifier

  # Dunno what is up, but I'd like to get basic func in.
  acts_as_authentic do |c|
    c.login_field(:email)
    c.email_field(:email)
    c.validate_email_field(false)
  end

  def noisy_unread
    Metadata.find_by_sql([METADATA_NOISY_UNREAD, self.id, self.id])
  end

  def has_read?(entry)

    # cannot be arsed to do this more efficient. It eats me away inside
    # that I could save a lot of indirection and redundant obj instantiation
    # but that would involve google and messing with connection objs.
    m = Metadata.find_by_sql(["select metadata.read from metadata where metadata.user_id = ? and metadata.entry_id = ?", self.id, entry.id])
    m.first.read unless m.first.nil?
     
  end

  def read!(entry)
    m = Metadata.find_or_create_by_user_id_and_entry_id(self.id, entry.id)
    m.read = Time.now
    m.save!

  end

  def signal_count
    Classification.count_by_sql("select count(id) from classifications where user_id = #{self.id} and liked is true")
  end

  def noise_count
    Classification.count_by_sql("select count(id) from classifications where user_id = #{self.id} and liked is false")
  end
  
  def liked?(entry)
    an_opinion = self.classification_for(entry)
    return false if an_opinion.nil?

    return an_opinion["liked"]
  end

  def disliked?(entry)
    an_opinion = self.classification_for(entry)
    return false if an_opinion.nil?
    
    return !an_opinion["liked"]
  end
  def classify_entry(value,entry)
    classify_name(value, entry.id)

  end


  def liked!(entry)
    classify("liked", true, entry.id)
  end

  def disliked!(entry)
    classify("liked", false, entry.id)
  end

  def liked
    Entry.find_by_sql(["select * from entries e where e.id = (select c.entry_id from classifications c where e.id = c.entry_id and c.liked is true and c.user_id = ?)", self.id])
  end

  def disliked
    Entry.find_by_sql(["select * from entries e where e.id = (select c.entry_id from classifications c where e.id = c.entry_id and c.liked is false and c.user_id = ?)", self.id])
  end

  def skipped
    Entry.find_by_sql(["select * from entries e where e.id in (select m.entry_id from metadata m where m.user_id = ? and m.read = ?) order by e.published", self.id, Metadata::SKIPPED])
  end

  def subscribe(sub)
    begin
      self.subscriptions.find(sub.id)
    rescue Exception => e
      User.connection.execute "INSERT INTO subscriptions_users(user_id, subscription_id, created_at) VALUES (#{self.id}, #{sub.id}, NOW());"
    end
  end

  def classification_for(entry)
    Classification.find_by_user_id(self.id,
                                   :conditions => { :entry_id => entry.id })
  end

  def metadata_for(entry)
    Metadata.find_by_user_id(self.id, 
                             :conditions => { :entry_id => entry.id })
  end

  def stream
    Stream.find_all_by_user_id(self.id)
  end

  private

  # temporary until this gets replaced with a more intelligent mechanism
  def set_modifier
    self.modifier = '1'
  end
  def classify_name( val, entry_id)
    c = Classification.find_or_create_by_entry_id(entry_id)
    c.user = self
    c['name'] = val
    c.save!
  end

  def classify(attribute, val, entry_id)
    c = Classification.find_or_create_by_entry_id(entry_id)
    c.user = self
    c[attribute] = val
    c.save!
  end

  private
  METADATA_NOISY_UNREAD = 
    "SELECT * FROM metadata m
     WHERE m.user_id = ?
     AND m.read IS NULL 
     AND m.signal IS FALSE
     AND m.entry_id NOT IN 
          (SELECT s.entry_id
           FROM stream s
           WHERE s.user_id = ?)"

end
