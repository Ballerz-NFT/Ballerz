import "MetadataViews"
import "Gaia"

access(all) fun main(owner: Address, nftID: UInt64): {String: String} {
    let collection = getAccount(owner).capabilities
        .borrow<&{Gaia.CollectionPublic}>(Gaia.CollectionPublicPath)
        ?? panic("could not borrow Gaia public collection at owner address")
    let nft = collection.borrowGaiaNFT(id: nftID)
        ?? panic("owner does not have NFT with that id")

    let display = Gaia.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionDisplay>())! as! MetadataViews.NFTCollectionDisplay
    return {
        "nft": (nft.resolveView(Type<MetadataViews.ExternalURL>())! as! MetadataViews.ExternalURL).url,
        "collection": display.externalURL.url,
        "squareImage": display.squareImage.file.uri(),
        "bannerImage": display.bannerImage.file.uri()
    }
}
