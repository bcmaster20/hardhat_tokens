
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * Hosokawa Zen
 * 2021/12/15
*/

abstract contract Feeable {
    using SafeMath for uint256;

    // --------------------- Fee Settings ------------------- //

    uint16 internal constant FEES_DIVISOR = 10**4;

    address internal burnAddress = 0x0000000000000000000000000000000000000000;
    address internal treasuryAddress = 0x6155711b7a66B1473C9eFeF10150340E69ea48de;    // Treasury Address

    mapping (address => bool) internal _isExcludedFromFee;

    constructor() {
        _addFees();
    }

    enum FeeType { Burn, Treasury }

    struct Fee {
        FeeType _type;
        uint256 _value;
        address _recipient;
    }
    Fee[] public fees;

    uint256 private sumOfFees;

    function _addFee(FeeType name, uint256 value, address recipient) private {
        fees.push( Fee(name, value, recipient ));
        sumOfFees += value;
    }

    function _addFees() private {
        _addFee(FeeType.Burn, 400, burnAddress);                          // Burn         4%
        _addFee(FeeType.Treasury, 90, treasuryAddress);                   // Treasury     0.9%
    }

    function _getFee(uint256 index) internal view returns (FeeType, uint256, address){
        require( index >= 0 && index < fees.length, "_getFee: Fee index out of bounds");
        Fee memory fee = fees[index];
        return ( fee._type, fee._value, fee._recipient);
    }

    function _getFeesCount() internal view returns (uint256) {
        return fees.length;
    }

    function getFeeTotal() internal view returns (uint256) {
        return sumOfFees;
    }
}

contract KzarToken is Context, IERC20, IERC20Metadata, Ownable, Feeable {
    using SafeMath for uint256;

    string private constant _name = "Kzar Token";
    string internal constant _symbol = "KZT";
    uint8 internal constant _decimals = 18;
    uint256 internal constant ZEROES = 10**uint256(_decimals);
    uint256 internal constant _total_supply = 10**6 * ZEROES;

    mapping (address => uint256) internal _balances;
    mapping (address => mapping (address => uint256)) internal _allowances;


    constructor(){
        _balances[msg.sender] = _total_supply;

        // exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        emit Transfer(address(0), owner(), _total_supply);
    }

    /** Functions required by IERC20 **/
    
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _total_supply;
    }

    function getOwner() public view returns (address) {
        return owner();
    }

    function balanceOf(address account) public view override returns (uint256){
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external override returns (bool){
        _transfer( msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256){
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve( msg.sender, spender, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ReflectionToken: approve from the zero address");
        require(spender != address(0), "ReflectionToken: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool){
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");

        _approve(sender, msg.sender, currentAllowance - amount);


        return true;
    }

    /**
 * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");

        _approve(_msgSender(), spender, currentAllowance - subtractedValue);


        return true;
    }

    /**
    * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "transfer from the zero address");
        require(recipient != address(0), "transfer to the zero address");
        require(sender != address(burnAddress), "transfer from the burn address");
        require(amount > 0, "Transfer amount must be greater than zero");

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");

        // indicates whether or not fee should be deducted from the transfer
        bool takeFee = true;

        // holds the fees value as per recipient address, used for anti-dumping mechanism
        uint256 sumOfFees = getFeeTotal();

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]) { takeFee = false; }

        // if the transaction is being performed on third-party application, take anti-dumping fee
//        if(_isIncludedInAntiDumping[recipient]) {
//            sumOfFees = getFeeTotal().add(antiDumpingFees);
//        }

        _transferTokens(sender, recipient, amount, takeFee, sumOfFees);
    }

    function _transferTokens(address sender, address recipient, uint256 amount, bool takeFee, uint256 sumOfFees) private {

        // uint256 sumOfFees = getFeeTotal();
        if ( !takeFee ) { sumOfFees = 0; }

        (uint256 tAmount, uint256 tTransferAmount) = _getValues(amount, sumOfFees);

        _balances[sender] = _balances[sender].sub(tAmount);
        _balances[recipient] = _balances[recipient].add(tTransferAmount);

        if ( sumOfFees > 0 ){
            _takeFees( amount );
        }
        
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _getValues(uint256 tAmount, uint256 feesSum) private pure returns (uint256, uint256) {

        uint256 tTotalFees = tAmount.mul(feesSum).div(FEES_DIVISOR);
        uint256 tTransferAmount = tAmount.sub(tTotalFees);

        return (tAmount, tTransferAmount);
    }

    function _takeFees(uint256 amount) private {

        uint256 feesCount = _getFeesCount();
        for (uint256 index = 0; index < feesCount; index++ ) {
            (FeeType _type, uint256 _value, address _recipient) = _getFee(index);

            if ( _type == FeeType.Burn ) {
                _burn( amount, _value );
            }
            else if ( _type == FeeType.Treasury) {
                _takeFee( amount, _value, _recipient );
            }
        }
    }

    function _burn(uint256 amount, uint256 fee) private {
        uint256 tBurn = amount.mul(fee).div(FEES_DIVISOR);

        _balances[burnAddress] = _balances[burnAddress].add(tBurn);
        /**
        *  Emit the event so that the burn address balance is updated
         */
        emit Transfer(msg.sender, burnAddress, tBurn);
    }

    function _takeFee(uint256 amount, uint256 fee, address recipient) private {

        uint256 tAmount = amount.mul(fee).div(FEES_DIVISOR);

        _balances[recipient] = _balances[recipient].add(tAmount);

        /**
        * Emit the event so that the burn address balance is updated
         */
        emit Transfer(msg.sender, recipient, tAmount);
    }
}
