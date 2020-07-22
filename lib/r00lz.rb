require "r00lz/version"
module R00lz
  class App
    def call(env) # Like proc#call
      kl, act = cont_and_act(env)
      text = kl.new(env).send(act)
      [200,
       {'Content-Type' => 'text/html'},
       [text]]
    end

    def cont_and_act(env)
      _, con, act, after =
        env["PATH_INFO"].split('/', 4)
      con = con.capitalize +
        "Controller"
      [Object.const_get(con), act]
    end
  end

  require "erb"
  class Controller
    attr_reader :env
    def initialize(env)
      @env = env
    end

    def render(name, b = binding())
      template = "app/views/#{name}.html.erb"
      e = ERB.new(File.read template)
      e.result(b)
    end

    def request
      @request ||= Rack::Request.new @env
    end

    def params
      request.params
    end
  end

  def self.to_underscore(s)
    s.gsub(
      /([A-Z]+)([A-Z][a-z])/,
      '\1_\2').gsub(
      /([a-z\d])([A-Z])/,
      '\1_\2').downcase
  end
end

class Object
  def self.const_missing(c)
    require R00lz.to_underscore(c.to_s)
    Object.const_get(c)
  end
end

class FileModel
  def initialize(fn)
    @fn = fn
    id = File.basename(fn,
      ".json").to_i
    cont = File.read fn
    @hash = JSON.load cont
  end

  def [](field)
    @hash[field.to_s]
  end

  def []=(field, val)
    @hash[field.to_s] = val
  end

  def self.find(id)
    self.new "data/#{id}.json"
  rescue
    nil
  end
end

require "sqlite3"
DB = SQLite3::Database.new "test.db"
class SQLModel
  def self.table
    R00lz.to_underscore name
  end

  def self.schema
    @schema ||= Hash[DB.table_info(table).map { |row|
      [ row["name"], row["type"] ]
    }]
  end

  def self.count
    DB.execute(<<SQL)[0][0]
SELECT COUNT(*) FROM #{table}
SQL
  end

  def self.to_sql(val)
    case val
    when NilClass
      'null'
    when Numeric
      val.to_s
    when String
      "'#{val}'"
    else
      raise "Can't change #{val.class} to SQL!"
    end
  end

  def self.create(values)
    keys = schema.keys - ["id"]
    vals = keys.map { |key| to_sql(values[key]) }

    DB.execute "INSERT INTO #{table} (#{keys.join ","}) VALUES (#{vals.join ","});"
    data = Hash[keys.map { |k| [k, values[k]] }]
    sql = "SELECT last_insert_rowid();"
    data["id"] = DB.execute(sql)[0][0]
    self.new data
  end

  def self.find(id)
    row = DB.execute("select #{schema.keys.join ","}" +
      " from #{table} where id = #{id};")
    self.new Hash[schema.keys.zip row[0]]
  end

  def self.all
    rows = DB.execute("select #{schema.keys.join ","}" +
      " from #{table};")
    rows.map do |row|
      self.new Hash[schema.keys.zip row]
    end
  end

  def initialize(data = {})
    @hash = data
  end

  def method_missing(name, *args)
    if name.to_s[-1] == '='
      col_name = name.to_s[0..-2]
      @hash[col_name] = args[0]
    else
      @hash[name.to_s]
    end
  end

  def save!
    fields = @hash.map do |k, v|
      "#{k}=#{SQLModel.to_sql(v)}"
    end.join ","

    DB.execute "UPDATE #{self.class.table} SET #{fields} " +
      "WHERE id = #{@hash["id"]}"
    true
  end

  def save
    self.save! rescue false
  end

end
