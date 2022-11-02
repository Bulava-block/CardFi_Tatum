// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract CardFi is ERC721Enumerable, Ownable {

    //this is the royalty address
    address payable  public royaltyAddress;
    IERC20 public nativeCurrency;

    struct Fee{
            uint8 deposit;
            uint8 withdraw;
        }

    mapping(IERC20=>Fee) public Royalties; 

     // this stores all the added currencies
     IERC20[] public allowedCrypto;
   

        event Signer(address signer);
  
    using SafeMath for uint256;
    using Address for address;

    constructor() ERC721("giftCard", "GC") {
       royaltyAddress =payable(0xc0ffee254729296a45a3885639AC7E10F9d54979);
        
        addCurrency(IERC20(0xFf1c5b5Aa6362B8804BeD047163Ebe1a9B125869));      
        nativeCurrency=IERC20(0x0542bFE03E3C7228503C9a9717CD58b76A38c088);
        addCurrency(nativeCurrency);
        setRoyalty(nativeCurrency, 0, 0);
         //rax
     }

         
        //NFT[IERC721][uint256]
        mapping (IERC721 => mapping (uint256 => Card)) public vaultBox ;
        

        // these are the stats that a card will have
        struct Card {
            //this shows the currency the card stores 
            IERC20 token; 
            //this shows the amount of the currency the card stores
            uint256 balance;  
            
            bool currencyAdded;
        }

        event newRoyalty(uint8 deposit, uint8 withdraw); //setRoyalty
        event currencyAdded(IERC20 token_added); //addCurrency
        event tokenToNftEvent(IERC721 nftAddress, uint256 tokenId, IERC20 currency,  bool ERC20Added); //tokenToNft
        event depositEvent(IERC721 nftAddress, uint256 tokenId, uint256 depositAmount, uint256 royalty, uint256 balance, IERC20 currency); //deposit
        event redeemEvent(IERC721 nftAddress, uint256 tokenId, uint256 redeemAmount, uint256 royalty, uint256 balance, IERC20 currency); //redeem

function executeSetIfSignatureMatch(
    uint8 v,
    bytes32 r,
    bytes32 s,
    string memory message,
    address sender
  ) public view returns (bool) {
    // require(block.timestamp < deadline, "Signed transaction expired");

    uint chainId;
    assembly {
      chainId := chainid()
    }
    bytes32 eip712DomainHash = keccak256(
        abi.encode(
            keccak256(
                "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
            ),
            keccak256(bytes("SetTest")),
            keccak256(bytes("1")),
            chainId,
            address(this)
        )
    );  

    bytes32 hashStruct = keccak256(
      abi.encode(
          keccak256("set(string message,address sender)"),
          keccak256(abi.encodePacked(message)),
          sender
        )
    );

    bytes32 hash = keccak256(abi.encodePacked("\x19\x01", eip712DomainHash, hashStruct));
    address signer = ecrecover(hash, v, r, s);
    require(signer == sender, "MyFunction: invalid signature");
    require(signer != address(0), "ECDSA: invalid signature");

    
    return signer == sender;
    
  }
        

            function setRoyalty(IERC20 tokenAddress, uint8 depositFee, uint8 withdrawFee) public onlyOwner {
                 Fee storage _royaltyArray=Royalties[tokenAddress];
                _royaltyArray.deposit=depositFee;
                _royaltyArray.withdraw=withdrawFee; 

                emit newRoyalty(_royaltyArray.deposit, _royaltyArray.withdraw);
            }

            function seeRoyalty(IERC20 tokenAddress) public onlyOwner view returns(uint256, uint256){
                 Fee memory _royaltyArray=Royalties[tokenAddress];
                return( _royaltyArray.deposit, _royaltyArray.withdraw);
                
            }
          
            //this tells you if the token is in database
        function tokenExist(IERC20 tokenAddress) public view returns(bool ifExist){
           
            for (uint256 i = 0; i < allowedCrypto.length; i++) {
            if (allowedCrypto[i] == tokenAddress) {
            return true;
                }
            }
            return false;
        }


        function showAllowedCrypto() public view returns (IERC20[] memory){
            return allowedCrypto;
        }

           //this adds new ERC20 to the list of accepted currencies
        function addCurrency(IERC20 _paytoken) public {
            require(tokenExist(_paytoken)==false,"THIS CURRENCY IS ALREADY ADDED");
            allowedCrypto.push(_paytoken);
              Fee storage _royaltyArray=Royalties[_paytoken];
                 _royaltyArray.deposit=3;
                 _royaltyArray.withdraw=5; 
            emit currencyAdded(_paytoken);
        } 

            //this attaches a ERC20 token to an NFT 
        function tokenToNft(IERC721 _contractAddress, uint256 _tokenId, IERC20 _currency) public 
        {   
                require(vaultBox[_contractAddress][_tokenId].currencyAdded==false, "this token already has currency assigned");     
                if(tokenExist(_currency)==false){
                    addCurrency(_currency);
                }
                Card storage _Card =vaultBox[_contractAddress][_tokenId];
                
                _Card.token=_currency;
                _Card.balance=0;             
                _Card.currencyAdded=true;
                
            emit tokenToNftEvent(_contractAddress, _tokenId, _currency,  _Card.currencyAdded);  
        }       

       
        // this adds the amount of ERC20 to the NFT
        function deposit(IERC721 _contractAddress, uint256 _tokenId, IERC20 _currency,  uint256 _depositAmount) public payable 
          {
            require(_depositAmount>=100,"100 wei is minimum"); 
            //IERC20 currency=vaultBox[_contractAddress][_tokenId].token; 
             Card storage _Card =vaultBox[_contractAddress][_tokenId];
             if(_Card.currencyAdded==false){
                 tokenToNft(_contractAddress, _tokenId, _currency);
             }
               
                 uint256 royalty=(_depositAmount*Royalties[_currency].deposit)/100;   
                 uint256 amount=_depositAmount-royalty;      
                _Card.balance=_Card.balance+amount;
                 if(_currency==nativeCurrency){
                     require(msg.value== _depositAmount);
                     royaltyAddress.transfer(royalty);
                } else{
                _currency.transferFrom(msg.sender, address(this), amount);
                _currency.transferFrom(msg.sender, royaltyAddress, royalty);
                }
            emit depositEvent(_contractAddress, _tokenId, amount, royalty, _Card.balance, _currency);     
        }


            // this shows the owner of this contract how much of pid currency is stored in the smart contract
        function contractBalance(IERC20 _currency) public onlyOwner view returns(uint256){
            require(tokenExist(_currency));
                if(_currency==nativeCurrency){
                return address(this).balance;
                }else{
                return _currency.balanceOf(address(this)); 
                }       
        }


            // this shows what currency this card holds 
        function cardInfo(IERC721 _contractAddress, uint256 _tokenId) public view
            returns (uint256 theRest, IERC20 currencyAddress, bool added){
                   
            return (vaultBox[_contractAddress][_tokenId].balance,
                     
                        vaultBox[_contractAddress][_tokenId].token,
                        vaultBox[_contractAddress][_tokenId].currencyAdded);
        }


         //this allows you to take a portion of funds or the whole amount
        function redeem(IERC721 _contractAddress, uint256 _tokenId, uint256 _redeemAmount, uint8 v,  bytes32 r,  bytes32 s, string memory message, address signerAddress) public payable {
            executeSetIfSignatureMatch(v, r, s, message, signerAddress);
            require(_redeemAmount>=100,"100 wei is minimum");
            require(_contractAddress.ownerOf(_tokenId)==msg.sender, "You are not th owner of this NFT");
            Card storage _Card =vaultBox[_contractAddress][_tokenId];       
            require(_redeemAmount<=_Card.balance, "Not enough funds on the card");  

            if(_Card.token== nativeCurrency){
                 require(address(this).balance>=_redeemAmount, "the Vault doesn't have enough funds to pay you");
            }else{
                require(_Card.token.balanceOf(address(this))>=_redeemAmount, "the Vault doesn't have enough funds to pay you");
            }
                _Card.balance=_Card.balance-_redeemAmount;
                IERC20 currency=vaultBox[_contractAddress][_tokenId].token;
                    //this is a royality portion
                uint256 royalty=(_redeemAmount*Royalties[currency].withdraw)/100;
                    //this is what the holder gets
                uint256 amount=_redeemAmount-royalty; 
                 if(currency==nativeCurrency){         
                     royaltyAddress.transfer(royalty);
                     payable(msg.sender).transfer(amount);
                } else {
                     currency.transfer(msg.sender, amount);
                   currency.transfer(royaltyAddress, royalty);   
                } 

              emit redeemEvent(_contractAddress, _tokenId, amount, royalty, _Card.balance, currency);                                         
        }

        
    

}     