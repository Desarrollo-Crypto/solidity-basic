// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

string constant SVG_START = '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500" fill="none" font-family="sans-serif"><defs><filter id="A" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse" height="500" width="500"><feDropShadow dx="1" dy="2" stdDeviation="8" flood-opacity=".67" width="200%" height="200%" /></filter><linearGradient id="B" x1="0" y1="0" x2="15000" y2="0" gradientUnits="userSpaceOnUse"><stop offset=".05" stop-color="#ad00ff" /><stop offset=".23" stop-color="#4e00ec" /><stop offset=".41" stop-color="#ff00f5" /><stop offset=".59" stop-color="#e0e0e0" /><stop offset=".77" stop-color="#ffd810" /><stop offset=".95" stop-color="#ad00ff" /></linearGradient><linearGradient id="C" x1="0" y1="60" x2="0" y2="110" gradientUnits="userSpaceOnUse"><stop stop-color="#d040b8" /><stop offset="1" stop-color="#e0e0e0" /></linearGradient></defs><path fill="url(#B)" d="M0 0h15000v500H0z"><animateTransform attributeName="transform" attributeType="XML" type="translate" from="0 0" to="-14500 0" dur="16s" repeatCount="indefinite" /></path><circle fill="#1d1e20" cx="100" cy="90" r="45" filter="url(#A)" /><text x="101" y="99" text-anchor="middle" class="nftLogo" font-size="32px" fill="url(#C)" filter="url(#A)">D_D<animateTransform attributeName="transform" attributeType="XML" type="rotate" from="0 100 90" to="360 100 90" dur="5s" repeatCount="indefinite" /></text><g font-size="32" fill="#fff" filter="url(#A)"><text x="250" y="280" text-anchor="middle" class="tierName">';
string constant SVG_END = "</text></g></svg>";
string constant TIER_NAME_0 ="Basic";
string constant TIER_NAME_1 ="Medium";
string constant TIER_NAME_2 ="Premium";
uint256 constant TIER_VALUE_0 = 0.01 ether;
uint256 constant TIER_VALUE_1 = 0.02 ether;
uint256 constant TIER_VALUE_2 = 0.05 ether;

contract TierNFT is ERC721, Ownable {

    uint public totalSupply;
    mapping(uint256 => uint256) public tokenTier;

    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol) {}

    function mint() public payable {
        require(msg.value >= TIER_VALUE_0, "Not enough value for the minimum tier");

        uint tierId = 0;
        if (msg.value >= TIER_VALUE_2) tierId = 2;
        else if (msg.value >= TIER_VALUE_1) tierId = 1;

        totalSupply++;
        _safeMint(msg.sender, totalSupply);
        tokenTier[totalSupply] = tierId;
    }

    /// @notice Create the tokenURI json here, instead of creating files individually
    /// @param _tokenId Token identifier number
    /// @return Token json metadata
    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(_tokenId), "Nonexistent token");

        // string memory imageSVG = "PLACEHOLDER FOR SVG IMAGE";
        string memory tierName = tokenTier[_tokenId] == 2
                    ? TIER_NAME_2
                    : tokenTier[_tokenId] == 1
                    ? TIER_NAME_1
                    : TIER_NAME_2;

        string memory imageSVG = string(
            abi.encodePacked(SVG_START, tierName, SVG_END)
        );

        // Base64.encode is for encoding the JSON into Base64 so browsers can translate it into a file much in the same way as a file attached to an email.
        string memory json = Base64.encode(
            bytes(
                // string( abi.encodePacked () ) concatenates the string
                string(
                    abi.encodePacked(
                        '{"name": "',name()," #",Strings.toString(_tokenId),
                        '", "description": "TierNFTs collection",'
                        // data:image/svg+xml;base64 tells the browser that the code after the comma is a string of text written in Base64 so the browser can decode it back into our SVG file format
                        '"image": "data:image/svg+xml;base64,', Base64.encode(bytes(imageSVG)),
                        '","attributes":[{"trait_type": "Tier", "value": "',tierName,
                        '" }]}'
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    /// @notice Function to withdraw funds from contract
    function withdraw() public onlyOwner {
        
        // Check that we have funds to withdraw
        uint256 balance = address(this).balance;
        require(balance > 0, "Balance should be > 0");

        // Withdraw funds.abi
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdraw failed");
    }

}