require "mail"

class IPDTest
  def self.gen_mail
    Mail.new do
      from	"Marcus <samson@indypicdump.com>"
      to	"receiver@indypicdump.com"
      subject	"this is a test"
      add_file 	"test/golden_gate_test.jpg"
    end
  end
end
