-- Credits to Killa
-- Last updated 8/29/26
-- Low chance of this working on modded versions of BAC

for _, Table in filtergc("table", {}) do
    if getrawmetatable(Table) then
        continue
    end

    local HasRecursiveTable = false

    for _, Value in Table do
        if type(Value) ~= "table" then
            continue
        end

        if Table == Value then
            HasRecursiveTable = true
            break
        end
    end

    if not HasRecursiveTable then
        continue
    end

    local BanIndex
    for _, Value in Table do
        if type(Value) ~= "number" then
            continue
        end

        for Index = 1, 3 do
            if Value ~= Index then
                continue
            end

            BanIndex = Index
            break
        end
    end

    if BanIndex and Table[BanIndex] == nil then
        setmetatable(Table, {
            __newindex = function() end
        })
    end
end