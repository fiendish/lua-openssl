local lu = require("luaunit")
local openssl = require("openssl")
local pkey = openssl.pkey
local unpack = unpack or table.unpack
local helper = require("helper")

local _, _, opensslv = openssl.version(true)
if opensslv <= 0x3000a000 or helper.libressl then
  print("SKIP SM2")
  return
end

TestSM2 = {}

function TestSM2:TestSM2()
  local nec = { "ec", "SM2" }

  local ec = pkey.new(unpack(nec))
  local t = ec:parse()
  if helper.openssl3 then
    lu.assertEquals(t.type, "SM2")
    t = t.sm2:parse(true) --make basic table
  else
    lu.assertEquals(t.type, "EC")
    t = t.ec:parse(true) --make basic table
  end
  lu.assertEquals(type(t.curve_name), "number")
  lu.assertStrContains(t.x.version, "bn library")
  lu.assertStrContains(t.y.version, "bn library")
  lu.assertStrContains(t.d.version, "bn library")

  local k1 = pkey.get_public(ec)
  assert(not k1:is_private())
  t = k1:parse()
  assert(not k1:missing_paramaters())
  assert(t.bits == 256)
  assert(t.type == (helper.openssl3 and "SM2" or "EC"), t.type)
  assert(t.size == 72)
  local r = helper.openssl3 and t.sm2 or t.ec
  t = r:parse(true) --make basic table
  lu.assertEquals(type(t.curve_name), "number")
  lu.assertStrContains(t.x.version, "bn library")
  lu.assertStrContains(t.y.version, "bn library")
  lu.assertEquals(t.d, nil)
  t = r:parse()
  lu.assertStrContains(tostring(t.pub_key), "openssl.ec_point")
  lu.assertStrContains(tostring(t.group), "openssl.ec_group")
  local x, y = t.group:affine_coordinates(t.pub_key)
  lu.assertStrContains(x.version, "bn library")
  lu.assertStrContains(y.version, "bn library")
  local ec2p = {
    alg = "ec",
    ec_name = t.group:parse().curve_name,
    x = x,
    y = y,
  }
  local ec2 = pkey.new(ec2p)
  assert(not ec2:is_private())

  t = ec:parse()
  t = helper.openssl3 and t.sm2 or t.ec
  ec2p.d = t:parse().priv_key
  local ec2priv = pkey.new(ec2p)
  assert(ec2priv:is_private())

  nec = { "ec", "SM2" }
  local key1 = pkey.new(unpack(nec))
  local key2 = pkey.new(unpack(nec))
  local ec1
  if helper.openssl3 then
    ec1 = key1:parse().sm2
    ec2 = key2:parse().sm2
  else
    ec1 = key1:parse().ec
    ec2 = key2:parse().ec
  end
  local secret1 = ec1:compute_key(ec2)
  local secret2 = ec2:compute_key(ec1)
  assert(secret1 == secret2)

  local pub1 = pkey.get_public(key1)
  local pub2 = pkey.get_public(key2)
  if helper.openssl3 then
    pub1 = pub1:parse().sm2
    pub2 = pub2:parse().sm2
  else
    pub1 = pub1:parse().ec
    pub2 = pub2:parse().ec
  end

  secret1 = ec1:compute_key(pub2)
  secret2 = ec2:compute_key(pub1)
  assert(secret1 == secret2)
end

function TestSM2:TestSM2_SignVerify()
  local nec = { "ec", "SM2" }
  local pri = pkey.new(unpack(nec))
  local pub = pri:get_public()
  local msg = openssl.random(33)

  local sig
  if not helper.openssl3 then
    sig = assert(pri:sign(msg, "sha256"))
    assert(pub:verify(msg, sig, "sha256"))
  end

  if pri.as_sm2 then
    -- OpenSSL v1.1.1
    assert(pri:as_sm2())
    assert(pub:as_sm2())
  end

  sig = assert(pri:sign(msg, "sm3"))
  assert(pub:verify(msg, sig, "sm3"))
end
