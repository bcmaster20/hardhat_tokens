pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTBurn {

    event Minted(address, address, uint256);

    constructor(){
    }

    function burnNFT(address account, address nftAddress, uint256 tokenId) external {
        IERC721 nft = IERC721(nftAddress);
        require(nft.ownerOf(tokenId) == account, "NFTBurn: is not owner");

        nft.approve(address(this), tokenId);
        nft.transferFrom(account, address(0), tokenId);

        emit Minted(account, nftAddress, tokenId);
    }
}