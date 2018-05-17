require 'c_hex'
require 'chariwt'
require 'cbor'
require 'base64'
require 'ecdsa'
require 'byebug'
require 'json'
require 'model/test_keys'

RSpec.describe Chariwt::VoucherSID do
  def test1
    {60200 => {
       -99=>"proximity",
       -98=> DateTime.new(2018,5,9,17,04,26),
       -89=>"00-D0-E5-01-00-09",
       -93=>"tM47HaAxjLNfSedTZQpaHg",
       -88=>"0\x82\x01\xD10\x82\x01V\xA0\x03\x02\x01\x02\x02\x01\x020\n\x06\b*\x86H\xCE=\x04\x03\x030q1\x120\x10\x06\n\t\x92&\x89\x93\xF2,d\x01\x19\x16\x02ca1\x190\x17\x06\n\t\x92&\x89\x93\xF2,d\x01\x19\x16\tsandelman1@0>\x06\x03U\x04\x03\f7#<SystemVariable:0x00000004f911a0> Unstrung Fountain CA0\x1E\x17\r171107234528Z\x17\r191107234528Z0C1\x120\x10\x06\n\t\x92&\x89\x93\xF2,d\x01\x19\x16\x02ca1\x190\x17\x06\n\t\x92&\x89\x93\xF2,d\x01\x19\x16\tsandelman1\x120\x10\x06\x03U\x04\x03\f\tlocalhost0Y0\x13\x06\a*\x86H\xCE=\x02\x01\x06\b*\x86H\xCE=\x03\x01\a\x03B\x00\x04\x96ePr4\xBA\x9F\xE5\xDD\xE6_\xF6\xF0\x81o\xE9H\x9E\x81\f\x12\a;F\x8F\x97d+c\x00\x8D\x02\x0FW\xC9|\x94\x7F\x84\x8C\xB2\x0Ea\xD6\xC9\x88\x8D\x15\xB4B\x1F\xD7\xF2j\xB7\xE4\xCE\x05\xF8\xA7L\xD3\x8B:\xA3\r0\v0\t\x06\x03U\x1D\x13\x04\x020\x000\n\x06\b*\x86H\xCE=\x04\x03\x03\x03i\x000f\x021\x00\xB4\f6\xEA\xDF\xF2\xDB\xF9\xD2TN\x0F\x90\xD0\\q\x0E$\x93V\xDD\x05v\x83\xD4\x04t4\xA4\xD8\xC6>\x02\x84\xAB\x05)\x86H\xD8\xE1\xE2\x89D:\x11..\x021\x00\x9E'Y\xF3p\xF8\x18\xDBfb\xA2\"%\x04q<\a2\x11\x95]\xA3\ac\xF1{\x9F\x7Fp\xC0\xA7\x01\x05#\xA7t\xD3\xEA\n\x93\x84.^\x9B\xABp\x99\xA9"
     }
    }
  end

  it "should translated a SID mapping back to a hash map" do
    nhash = Chariwt::VoucherSID.yangsid2hash(test1)
    expect(nhash['assertion']).to eq("proximity")
    expect(nhash['serial-number']).to eq("00-D0-E5-01-00-09")
  end


end