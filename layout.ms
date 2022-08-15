try DestroyDialog mainRollout catch

/* ジオメトリレイヤーを取得する */
fn getGeoLayers =
(
    local geosLayerPattern = @"30_[A-Z]{3,}_geos"
    local geosLayerRgx = dotnetObject \
        "System.Text.RegularExpressions.Regex" geosLayerPattern
    local geoLayerPattern = @"\d{2}_[A-Z]{3,}_[a-z]{3,}_"
    local geoLayerRgx = dotnetObject \
        "System.Text.RegularExpressions.Regex" geoLayerPattern
    local layers = #()

    for i = 0 to LayerManager.count - 1 do
    (
        local parent = LayerManager.getLayer i
        if geosLayerRgx.IsMatch parent.name do
        (
            local num = parent.getNumChildren ()
            for i = 1 to num do
            (
                local layer = (parent.getChild i).name
                if geoLayerRgx.IsMatch layer do
                    append layers layer
            )
        )
    )
    
    return layers
)

/* ジオメトリレイヤーの名前を簡略化する */
fn simplifyGeoLayerName layerName =
(
    local pattern = @"\d{2}_[A-Z]{3,}_[a-z]{3,}_"
    local rgx = dotnetObject "System.Text.RegularExpressions.Regex" pattern

    return (rgx.Replace layerName "")
)

/* レイヤーの可視性を設定する */
fn setLayersVisiblity layers isVisible =
(
    if ClassOf isVisible == BitArray then
		for i = 1 to layers.count do
            (LayerManager.getLayerFromName layers[i]).on = isVisible[i]
    else
        for l in layers do
            (LayerManager.getLayerFromName l).on = isVisible
)

/* レイヤーの可視性を取得する */
fn getLayersVisiblity layers =
(
    local isVisible = #{}
    isVisible.count = layers.count

    for i = 1 to layers.count do
        isVisible[i] = (LayerManager.getLayerFromName layers[i]).on

    return isVisible
)

rollout mainRollout "Layout Helper"
(
    local initialGeoLayers = #()
    local geoLayers = #()
    local renderLayers = #()
    local renderLayerNames = #()
    local outputPath = undefined
    local outputMetadata = undefined
    group "Geometry Layers"
    (
        multiListBox  geoLayerList ""
        button createRenderlayer "Create New" width:120
    )
    group "Render Layers"
    (
        multiListBox  renderLayerList ""
        button removeRenderlayer "Delete" width:120
    )
    group "Output"
    (
        edittext filepath width:125 across:2 align:#left 
        button selectFilepath "File..." align:#right
        button runRendering "Render Image" width:120
        button exportToPSD "Export to PSD" width:120
    )
    group "About"
    (
        label version "Layout Helper v1.1"
    )
    on mainRollout open do
    (
        /* 表示の初期化 */
        initialGeoLayers = getGeoLayers ()
        sort initialGeoLayers
        geoLayers = copy initialGeoLayers #noMap
        geoLayerList.items = geoLayers

        -- デフォルトの出力パスを設定する
        -- 初期設定：RGB48ビットの透過png画像
        outputPath = (getDir #renderoutput) + @"\{LayerName}.png"
        outputMetadata = #(2, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0)
        filepath.text = outputPath
    )
    on createRenderlayer pressed do
    (
        /* 新規レンダーレイヤーを作成 */
        local selection = geoLayerList.selection
        local layerIndexies = #()
        local layers = #()
        local layerName = ""

        -- 選択ジオメトリレイヤーのインデックスを取得する
        for i = 1 to selection.count do
            if selection[i] do
                append layerIndexies i
        
        -- レンダーレイヤーに追加するジオメトリレイヤーのリストを作成する
        for i in layerIndexies do
            append layers geoLayers[i]

        -- レンダーレイヤーの名前を生成する
        for i = 1 to amin(#(3, layers.count)) do
            layerName += "_" + (simplifyGeoLayerName layers[i])
        if layers.count > 3 do layerName += "_and_more"
        layerName = substring layerName 2 -1
        
        -- レンダーレイヤーに追加したジオメトリレイヤーを削除する
        for i = layerIndexies.count to 1 by -1 do
            deleteItem geoLayers layerIndexies[i]
        
        -- レンダーレイヤーを追加する
        if layerIndexies.count > 0 do
        (
            append renderLayers layers
            append renderLayerNames layerName
        )
        
        -- ロールアウトの表示を更新する
        geoLayerList.items = geoLayers
        renderLayerList.items = renderLayerNames
    )
    on removeRenderlayer pressed do
    (
        /* レンダーレイヤーを削除 */
        local selection = renderLayerList.selection
        local layerIndexies = #()

        -- 選択レンダーレイヤーのインデックスを取得する
        for i = 1 to selection.count do
            if selection[i] do
                append layerIndexies i

        -- レンダーレイヤーに追加していたレイヤーをジオメトリレイヤーに戻す
        for i in layerIndexies do
            join geoLayers renderLayers[i]
        sort geoLayers
        
        -- レンダーレイヤーを削除する
        for i = layerIndexies.count to 1 by -1 do
        (
            deleteItem renderLayers layerIndexies[i]
            deleteItem renderLayerNames layerIndexies[i]
        )

        -- ロールアウトの表示を更新する
        geoLayerList.items = geoLayers
        renderLayerList.items = renderLayerNames
    )
    on selectFilepath pressed do
    (
        /* 出力先を設定する */
        outputPath = getBitmapSaveFilename \
            caption:"Rendering Output File" \
            filename:filepath.text metadata:&outputMetadata
        if outputPath != undefined do filepath.text = outputPath
    )
    fn renderImage index elements filename =
    (
        -- レンダリングするレイヤーのみを表示する
        setLayersVisiblity initialGeoLayers false
        setLayersVisiblity renderLayers[index] true

        -- レンダリングする
        local path = substituteString \
            filename "{LayerName}" renderLayerNames[index]
        local imgs = #()
        local img = render vfb:false renderElementBitmaps:&imgs
        img.filename = path
        save img metadata:outputMetadata

        -- レンダーエレメント別に画像を保存する
        for j = 1 to elements.NumRenderElements () do
        (
            local elm = elements.GetRenderElement (j - 1)
            local name = elm.elementName
            local metadata = ElementGetMetaData elm
            if metadata.count == 0 do metadata = outputMetadata
            imgs[j].filename = substituteString path "." ("_" + name + ".")
            save imgs[j] metadata:metadata
        )
    )
    on runRendering pressed do
    (
        /* レンダリングを開始 */
        -- 最初の状態を記録しておく
        local isVisible = getLayersVisiblity initialGeoLayers
        local renderElements = MaxOps.GetCurRenderElementMgr ()

        -- レンダリングする
        for i = 1 to renderLayers.count do
            if outputPath != undefined do
                renderImage i renderElements outputPath

        -- 最初の状態に戻す
        setLayersVisiblity initialGeoLayers isVisible
    )
    on exportToPSD pressed do
    (
        /* レンダリングを実行して結果をPSDに保存 */
        -- 最初の状態を記録しておく
        local isVisible = getLayersVisiblity initialGeoLayers
        local renderElements = MaxOps.GetCurRenderElementMgr ()

        -- 一時的にここに書き出す
        local path = (getDir #renderoutput) + @"\.tmp\{LayerName}.png"

        -- レンダリングする
        for i = 1 to renderLayers.count do
            if outputPath != undefined do
                renderImage i renderElements path

        -- 最初の状態に戻す
        setLayersVisiblity initialGeoLayers isVisible

        -- Photoshopに接続する
        pshop = CreateOLEObject "Photoshop.Application"
        pshop.Visible = true -- デバッグが済んだらfalseにする

        /* ここに処理が入る */

        -- Photoshopを切断する
        releaseAllOLEObjects pshop

        -- 書き出した画像は削除する
        /* ここに処理が入る */
    )
)

CreateDialog mainRollout width: 200