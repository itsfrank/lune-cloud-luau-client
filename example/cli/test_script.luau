local as = game:GetService("AssetService")

local user_id = 1699751624

function make_image()
    local dim = 70
    local ei = as:CreateEditableImage({ Size = Vector2.new(dim, dim) }) :: EditableImage
    ei:DrawRectangle(
        Vector2.new(0, 0),
        Vector2.new(dim, dim),
        Color3.new(0.15, 0.15, 0.20),
        0,
        Enum.ImageCombineType.BlendSourceOver
    )
    ei:DrawRectangle(Vector2.new(10, 10), Vector2.new(10, 10), Color3.new(1, 1, 0), 0, Enum.ImageCombineType.Overwrite)
    ei:DrawRectangle(
        Vector2.new(dim - 20, 10),
        Vector2.new(10, 10),
        Color3.new(0, 1, 1),
        0,
        Enum.ImageCombineType.Overwrite
    )
    ei:DrawRectangle(
        Vector2.new(10, dim - 20),
        Vector2.new(dim - 20, 10),
        Color3.new(1, 0, 1),
        0,
        Enum.ImageCombineType.Overwrite
    )
    ei:DrawRectangle(
        Vector2.new(5, dim - 25),
        Vector2.new(10, 10),
        Color3.new(1, 0, 1),
        0,
        Enum.ImageCombineType.Overwrite
    )
    ei:DrawRectangle(
        Vector2.new(dim - 15, dim - 25),
        Vector2.new(10, 10),
        Color3.new(1, 0, 1),
        0,
        Enum.ImageCombineType.Overwrite
    )
    return ei
end

-- make a tetrahedron
function make_tetrahedron(): EditableMesh
    local em = as:CreateEditableMesh() :: EditableMesh
    local top = em:AddVertex(Vector3.new(0, 10, 0))
    local b_m = em:AddVertex(Vector3.new(0, 0, 10))
    local b_l = em:AddVertex(Vector3.new(10, 0, -10))
    local b_r = em:AddVertex(Vector3.new(-10, 0, -10))

    em:AddTriangle(b_m, b_r, b_l)
    em:AddTriangle(top, b_l, b_r)
    em:AddTriangle(top, b_m, b_l)
    em:AddTriangle(top, b_r, b_m)
    return em
end

local img_id, msh_id, mdl_id, plg_id = nil, nil, nil, nil

local _ = nil
print("start img upload")
local ei = make_image()
local img_id = as:CreateAssetAsync(ei, Enum.AssetType.Image, {
    Name = "Foo-img",
    CreatorId = user_id,
    CreatorType = Enum.CreatorType.User,
})
print("done img upload")

-- print("start msh upload")
-- local em = make_tetrahedron()
-- local msh_id = as:CreateAssetAsync(em, Enum.AssetType.Mesh, {
--     Name = "Foo-msh",
--     CreatorId = user_id,
--     CreatorType = Enum.CreatorType.User,
-- })
-- print("done msh upload")

local mdl = Instance.new("Folder")
local script = Instance.new("Script", mdl)
script.Source = `print("hello from oc plugin")`
-- print("start model upload")
-- _, mdl_id = as:CreateAssetAsync(mdl, Enum.AssetType.Model, {
--     Name = "Foo-mdl",
--     CreatorId = user_id,
--     CreatorType = Enum.CreatorType.User,
-- })
-- print("done model upload")

-- print("start plugin upload")
-- _, plg_id = as:CreateAssetAsync(mdl, Enum.AssetType.Plugin, {
--     Name = "Foo-plg",
--     CreatorId = user_id,
--     CreatorType = Enum.CreatorType.User,
-- })
-- print("done plugin upload")

return {
    message = "uploaded new asset",
    img_id = img_id,
    msh_id = msh_id,
    mdl_id = mdl_id,
    plg_id = plg_id,
}
