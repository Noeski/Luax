Luax
====

What's Luax?
------------

* Static typing
* Classes
* Variables are local by default
* ... 

Example
-------

```
class Bird
  String species
  
  function fly()
    print("WOOOOSH")
  end
end

Bird eagle = Bird()
eagle:fly()
```

produces:

```Lua
Bird = Bird or setmetatable({}, ...)

function Bird:fly()
  print("WOOOOOSH")
end

local eagle = Bird()
eagle:fly()
```
The Complete Syntax of Luax
---------------------------

[EBNF](docs/EBNF.md)
