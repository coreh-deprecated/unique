# ## Generating a UUID
# A UUID is a string of 32 hex digits, used to uniquely identify an object.
#
# The `generate` function generates a new UUID. UUIDs generated by this function
# *do not* conform with [RFC4122](http://tools.ietf.org/html/rfc4122). This is by
# design, as it's currently only possible to generate version 4 UUIDs on browser
# environments. Since we can't guaranty that `Math.random()` implementations are good
# enough to avoid collisions, the system time and date is also used when generating UUIDs
# to reduce the odds of collisions.
#
# This approach is similar to [the one](http://wiki.apache.org/couchdb/HttpGetUuids) used
# by CouchDB when using the `utc_random` algorithm.
#
# Generated UUID format:
# 
#        14 hex digits -> number of microseconds since the unix epoch
#       ______|_____
#      |            |
#      |            |  18 hex digits -> Pseudo-random numbers
#      |            | ________|_______
#      |            ||                |
#     "049fde01cd4d0731ff243eedc13b6915"
exports.generate: () ->
  # ### Initialization
  # First, we get references to `Math` functions to make the code shorter.
  # Then, we store the value we should multiply the result of `r()` to generate up to 6 hex digits of random data.
  r = Math.random; f = Math.floor
  s = 0xFFFFFF
  # ### Padding data to a fixed size
  # The UUID generation requires that some blocks of data are of a specific size
  # this function pads a string until it reaches a specified number of digits
  pad = (str, digits, char = '0') ->
    str = char + str while str.length < digits
    str
  # ### First 14 hex digits
  # First 14 hex digits are the number of microseconds since the unix epoch. Since
  # on the browser environment we can't get the time with a microsecond precision (only with a millisecond precision)
  # we pad the last 3 decimal digits with a random value on the interval [0, 1000[ before converting to hex.
  part1 = pad(f((new Date).getTime() * 1000 + r() * 1000).toString(16), 14)
  # ### Last 18 hex digits
  # Last 18 hex digits are random data. We generate them in three blocks
  # of 6 digits to avoid precision issues.
  part2 = pad(f(r() * s).toString(16), 6) +
    pad(f(r() * s).toString(16), 6) +
    pad(f(r() * s).toString(16), 6)
  uuid = part1 + part2

# ## Patching UUID Generator to Classes
# The `patch` function will add UUID generation functionality to a class, that is, it will
# add the `getUUID` method to the class prototype.
# The `getUUID` method returns the UUID of a object. UUIDs are generated lazily,
# on the first time `getUUID()` is called for that object. Subsequent calls return the same UUID
# Generated uuids are stored on the `__uuid` property of the object.
exports.patch: (someClass) ->
    someClass::getUUID = () ->
        @__uuid ?= exports.generate()

# ## Testing the UUID generator
exports.__test = () ->
  # UUIDs must have exactly 32 digits.
  uuid = UUID.generate()
  throw new Error 1 if uuid.length != 32

  # UUID.bind must work.  
  class UUIDTester
    constructor: () ->
  UUID.bind UUIDTester
  
  uuidtester = new UUIDTester
  throw new Error 2 if not uuidtester.getUUID?
  
  uuid = uuidtester.getUUID()
  throw new Error 3 if uuid.length != 32
  throw new Error 4 if uuidtester.__uuid != uuid