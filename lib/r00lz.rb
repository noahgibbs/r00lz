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

  class Controller
    attr_reader :env
    def initialize(env)
      @env = env
    end
  end
end
